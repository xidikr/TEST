# TEST

Sandbox repository for the **Cursor agent pipeline** described in
[`agent_pipeline_onboarding_for_teammate.md`](https://github.com/xidikr/TEST).

## What's in here

| File | Purpose |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Operating manual for Cursor agents and (future) Codex reviewer; defines workflow rules and P0/P1/P2/P3 review classifications. |
| [`scripts/verify.sh`](scripts/verify.sh) | The single source of truth for local + CI verification. Auto-detects C++ (CMake) and Python (uv / pip) toolchains; no-op steps when neither is present. |
| [`.github/workflows/ci.yml`](.github/workflows/ci.yml) | CI workflow whose final step is `bash ./scripts/verify.sh` — same as local. |
| [`.cursor/rules/00-workflow.mdc`](.cursor/rules/00-workflow.mdc) | `alwaysApply` rules locking Cursor agents into the pipeline discipline. |
| [`.cursor/commands/ship.md`](.cursor/commands/ship.md) | `/ship` slash command — canonical 11-step procedure for any non-trivial change. |
| [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md) | 4-section PR body template (Summary / Test plan / Risk / Related). |

## How to make a change

In Cursor chat:

```
/ship <one-sentence description of the change>
```

The agent will:

1. Sync `main` with `origin/main`.
2. Create a `<type>/<short-slug>` branch.
3. Make focused edits.
4. Run `bash scripts/verify.sh` until it prints `ALL GREEN`.
5. Commit with a conventional message (`feat:` / `fix:` / `chore:` / `docs:` / ...).
6. Push, open a PR via REST API, enable auto-merge, watch CI.
7. After CI greens and branch protection allows, the PR squash-merges and the head branch auto-deletes.

See [`.cursor/commands/ship.md`](.cursor/commands/ship.md) for the full procedure.

## Quick recipes

Common day-to-day tasks, with the exact phrasing that triggers the `/ship` skill cleanly.

| Task | Say this in Cursor chat |
|---|---|
| Fix a typo in a file | `/ship fix typo in <file>: <wrong> -> <right>` |
| Add a new section to a doc | `/ship docs: add <section title> section to <file>` |
| Add a small feature | `/ship feat: add <feature> to <module>` |
| Update CI workflow | `/ship ci: <what changes in .github/workflows>` |
| Bump a dependency version | `/ship chore: bump <dep> from <old> to <new>` |
| Add a test for an existing function | `/ship test: cover <function> with edge-case checks` |

The agent picks the branch type prefix automatically from the verb in your sentence (`fix:` → `fix/`, `add` → `feat/`, `update` → `chore/` or `ci/`, etc.). If you want to override, say it explicitly:

```
/ship as docs: rename "Branch protection" section to "Protection rules"
```

## Branch protection (status)

`main` is protected with:

- PR required (no direct push).
- Status check `build` must be green before merge.
- Branch must be up-to-date before merge.
- Admins cannot bypass.
- No force-pushes, no deletions.

To inspect:

```bash
gh api repos/xidikr/TEST/branches/main/protection
```
