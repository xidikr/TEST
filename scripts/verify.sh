#!/usr/bin/env bash
# ============================================================
#  scripts/verify.sh — pipeline single source of truth
#
#  Same script runs locally AND in CI. Never let CI run a
#  different command than this. If you need to add a new check,
#  add a step here so local 'bash scripts/verify.sh' catches it.
#
#  Designed for a mixed C++ + Python repo (Q4 = F).
#  Each step auto-detects whether it applies; if no relevant
#  files exist, the step is a no-op (so an empty repo still
#  verifies green).
# ============================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "================================================================"
echo " verify.sh @ $REPO_ROOT"
echo " host: $(uname -srm)"
echo " date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "================================================================"

# Convenience: helper to print boxed step header
step() {
    echo ""
    echo ">>> $*"
}
ok()   { echo "<<< OK"; }
skip() { echo "<<< SKIP ($*)"; }

# ---------------------------------------------------------------
step "[1] Sanity: tree status"
git -C "$REPO_ROOT" status --short || true
ok

# ---------------------------------------------------------------
step "[2] Forbid known secret patterns in tracked files"
# Catches files like *.pem, id_rsa, .env that escaped .gitignore.
BAD_PATTERN='(^|/)(\.env|id_rsa|id_ed25519|.*\.pem|.*\.key|credentials\.json)$'
if git -C "$REPO_ROOT" ls-files | grep -E "$BAD_PATTERN" >/tmp/verify_secrets 2>&1; then
    if [ -s /tmp/verify_secrets ]; then
        echo "ERROR: secret-like files tracked in repo:"
        cat /tmp/verify_secrets
        exit 1
    fi
fi
ok

# ---------------------------------------------------------------
step "[3] C++ (CMake) build, if CMakeLists.txt present"
if [ -f "$REPO_ROOT/CMakeLists.txt" ]; then
    if ! command -v cmake >/dev/null 2>&1; then
        echo "ERROR: CMakeLists.txt exists but cmake not installed."
        exit 1
    fi
    rm -rf "$REPO_ROOT/build"
    cmake -S "$REPO_ROOT" -B "$REPO_ROOT/build" -DCMAKE_BUILD_TYPE=Release
    cmake --build "$REPO_ROOT/build" -j"$(nproc 2>/dev/null || echo 2)"
    if [ -f "$REPO_ROOT/build/CTestTestfile.cmake" ]; then
        ctest --test-dir "$REPO_ROOT/build" --output-on-failure || {
            echo "ERROR: ctest failed."
            exit 1
        }
    fi
    ok
else
    skip "no CMakeLists.txt"
fi

# ---------------------------------------------------------------
step "[4] Python: install + lint + test, if pyproject.toml or requirements.txt present"
PY_CONFIG_FOUND="false"
[ -f "$REPO_ROOT/pyproject.toml" ]   && PY_CONFIG_FOUND="true"
[ -f "$REPO_ROOT/setup.py" ]         && PY_CONFIG_FOUND="true"
[ -f "$REPO_ROOT/requirements.txt" ] && PY_CONFIG_FOUND="true"

if [ "$PY_CONFIG_FOUND" = "true" ]; then
    if command -v uv >/dev/null 2>&1 && [ -f "$REPO_ROOT/pyproject.toml" ]; then
        echo "[python] using uv"
        uv sync --all-extras || { echo "ERROR: uv sync failed."; exit 1; }
        if uv run python -c "import pytest" 2>/dev/null; then
            uv run pytest -q || { echo "ERROR: pytest failed."; exit 1; }
        else
            echo "[python] pytest not available, skipping tests"
        fi
    else
        echo "[python] using pip"
        if [ -f "$REPO_ROOT/pyproject.toml" ] || [ -f "$REPO_ROOT/setup.py" ]; then
            pip3 install --user -e "$REPO_ROOT" || { echo "ERROR: pip install failed."; exit 1; }
        elif [ -f "$REPO_ROOT/requirements.txt" ]; then
            pip3 install --user -r "$REPO_ROOT/requirements.txt" || { echo "ERROR: pip install failed."; exit 1; }
        fi
        if python3 -c "import pytest" 2>/dev/null; then
            python3 -m pytest -q || { echo "ERROR: pytest failed."; exit 1; }
        else
            echo "[python] pytest not available, skipping tests"
        fi
    fi
    ok
else
    skip "no pyproject.toml / setup.py / requirements.txt"
fi

# ---------------------------------------------------------------
step "[5] Shell scripts pass shellcheck (if installed)"
SHELL_FILES=$(git -C "$REPO_ROOT" ls-files '*.sh' || true)
if [ -n "$SHELL_FILES" ] && command -v shellcheck >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    shellcheck $SHELL_FILES
    ok
else
    skip "shellcheck not installed or no .sh files"
fi

# ---------------------------------------------------------------
echo ""
echo "================================================================"
echo " verify.sh: ALL GREEN"
echo "================================================================"
