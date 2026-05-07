# Troubleshooting

Common situations you may hit while using the agent pipeline on `xidikr/TEST`,
plus the one-line fix for each.

---

## I ran `/ship X` but the agent says "preflight failed: scripts/verify.sh missing"

You're in the wrong directory. The skill activates only inside a repo that has the pipeline scaffolding. `cd` to the repo root and try again:

```bash
cd ~/桌面/test
```

If you're sure you're in the right repo and `verify.sh` is missing, the repo wasn't bootstrapped — see `agent_pipeline_onboarding_for_teammate.md`.

---

## CI keeps failing on `bash: scripts/verify.sh: Permission denied`

The executable bit was lost in a commit. Re-add it:

```bash
chmod +x scripts/verify.sh
git update-index --chmod=+x scripts/verify.sh
git commit -am "fix: chmod +x scripts/verify.sh"
git push
```

---

## `gh pr merge --auto` says "auto-merge is not allowed for this repository"

Owner needs to enable it once at https://github.com/xidikr/TEST/settings → Pull Requests → tick **Allow auto-merge**. After that, all future PRs work.

---

## A PR sat for 2 minutes then merged — but I expected it to wait for CI

CI duration is usually 6-30 seconds for this repo because `verify.sh` SKIPs the toolchain steps (no `CMakeLists.txt` / `pyproject.toml` at root yet). When real code lands those steps will start running and CI will take longer. The flow is identical; just slower.

---

## A PR is stuck "Waiting for status to be reported" forever

CI didn't start. Two common causes:

1. **Workflow file syntax error** — open https://github.com/xidikr/TEST/actions and look for a red "Workflow failed" entry; click for the error.
2. **Actions disabled at repo level** — check https://github.com/xidikr/TEST/settings/actions and ensure permissions are `Allow all actions and reusable workflows`.

---

## I want to ship a change but `/ship` keeps refusing

Check what the script printed. Most common reasons:

- **Worktree has untracked files you don't recognize** — likely your parallel work in another window. Stash or move aside before `/ship`.
- **Branch name doesn't match the regex** — must be `<type>/<slug>` where `<type>` ∈ `{feat, fix, chore, docs, refactor, test, ci}`.
- **Commit message format wrong** — must be `<type>: <short imperative>`.
- **PR body file missing required headers** — must contain `## Summary`, `## Test plan`, `## Risk`, `## Related`.

---

## I accidentally pushed to main directly somehow

Branch protection should have blocked it. If it didn't, run the protection self-check:

```bash
gh api repos/xidikr/TEST/branches/main/protection \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('required_status_checks',{}).get('contexts'))"
```

Expected output: `['build']`. If you see `[]` or `None`, the protection is broken — re-do `agent_pipeline_onboarding_for_teammate.md` § 5.2 and re-add `build` to the required checks list.

---

## I want to undo a merged PR

```bash
git checkout main
git pull --ff-only
git revert <merge-sha>
git push origin main
```

`git push origin main` will be **rejected by branch protection** (which is correct — direct push to main is forbidden). Wrap the revert in a fresh `/ship` instead:

```bash
git checkout -b fix/revert-pr-N
git revert <merge-sha>
# then ship.sh deliver "fix: revert PR #N — <reason>" /tmp/pr-body.md
```

---

## Where else to look

- `AGENTS.md` § 8 — symptom-to-action table for the same kind of issues
- `agent_pipeline_onboarding_for_teammate.md` § 8 (12 known pits) and § 9 (fault diagnosis)
