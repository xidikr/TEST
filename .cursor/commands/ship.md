# /ship — canonical 11-step ship procedure

Use this command for **any non-trivial change** to `xidikr/TEST`. The user invokes it as:

```
/ship <one-sentence change description>
```

The agent then executes the 11 steps below in order, reporting after each step. **Never skip a step.** If a step fails, **stop and tell the user**; do not paper over it.

---

## Step 1. Sync local `main` with `origin/main`

```bash
cd <repo-root>
git fetch origin
git checkout main
git pull --ff-only origin main
```

If `--ff-only` rejects (you have local commits on main), **stop**. The user committed something to local main outside the pipeline — surface it.

## Step 2. Create a focused feature branch

Naming: `<type>/<short-slug>`. Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`. Slug is lowercase, hyphenated, ≤ 5 words.

Examples:
- `fix/clamp-velocity-in-pd-controller`
- `feat/add-readme-quickstart`
- `chore/bump-cmake-min-version`
- `docs/explain-verify-skip-logic`

```bash
git checkout -b <branch>
```

## Step 3. Make focused edits

- One logical change per PR. If you find an unrelated bug, **note it for a follow-up PR**, do not fold it in.
- If editing existing files (`AGENTS.md`, `.gitignore`, `.cursor/rules/*`), **append, do not overwrite**.
- Do not commit secrets — `.gitignore` should already cover them; if `git status` shows something suspicious, **ask before adding**.

## Step 4. `bash scripts/verify.sh` must pass locally

```bash
bash scripts/verify.sh
```

If it fails: read the failing step, **fix the code**, do not loosen `verify.sh`. Re-run until it prints `ALL GREEN`.

## Step 5. Commit with conventional message

```bash
git add <only your changed files — never git add -A blindly>
git status                # verify diff matches expectation
git commit -m "<type>: <short imperative under 60 chars>"
```

Example: `git commit -m "fix: clamp velocity in PD controller"`.

## Step 6. Push the branch

```bash
git push -u origin <branch>
```

If push fails with `Permission denied (publickey)`: SSH issue — confirm `ssh -T git@github.com` returns `Hi xidikr!`. Do not switch to HTTPS silently.

## Step 7. Open the PR (use REST API, not `gh pr create`)

`gh pr create` sometimes races GitHub GraphQL indexing right after a fresh push and reports `No commits between main and ...`. The REST API is faster and reliable.

Write the PR body to a temp file first:

```bash
cat > /tmp/pr-body.md <<'EOF'
## Summary
<1–3 sentences on what changed and why>

## Test plan
- [ ] `bash scripts/verify.sh` passes locally
- [ ] CI green on head SHA
- [ ] (any feature-specific manual checks)

## Risk
<What can go wrong? Who/what is affected? Rollback notes.>

## Related
<Linked issues, prior PRs, upstream references, or "none">
EOF
```

Then open the PR:

```bash
gh api repos/xidikr/TEST/pulls \
  -X POST \
  -f title="<type>: <short imperative>" \
  -f head="<branch>" \
  -f base="main" \
  -F body=@/tmp/pr-body.md
```

Capture the PR number from the response (`.number`).

## Step 8. Enable auto-merge (squash, delete branch)

```bash
gh pr merge <pr-number> --squash --auto --delete-branch
```

This **does not merge immediately**; it tells GitHub "merge as soon as branch protection conditions are satisfied" (CI green + any required reviews). If branch protection is correctly set, the PR will sit and wait for CI.

If `gh pr merge` says "auto-merge not enabled for this repository": go to https://github.com/xidikr/TEST/settings → Pull Requests → tick **Allow auto-merge**. Tell the user.

## Step 9. Watch CI

```bash
gh pr checks <pr-number> --watch
```

If CI goes red:
- Read the failing job log: `gh run view --log-failed <run-id>`.
- Fix the code in your branch.
- Push the fix; auto-merge stays armed and will fire on the new green CI run.
- **Do not loosen `verify.sh` to make CI pass.**

If CI takes > 10 minutes when expected to be < 5: check `https://www.githubstatus.com/`. If GitHub is healthy, the workflow probably needs caching (see onboarding doc 坑 #10).

## Step 10. Verify the merge

After CI greens and auto-merge fires, verify:

```bash
gh pr view <pr-number> --json state,mergedAt,mergeCommit
git checkout main
git pull --ff-only origin main
git branch -d <branch>           # local cleanup; remote was already auto-deleted
```

Expected: `state == "MERGED"`, `mergedAt` populated, `mergeCommit.oid` is the new SHA on `main`.

## Step 11. Report to user

Final report message:

```
✅ Shipped: <PR title>
   PR:    https://github.com/xidikr/TEST/pull/<num>
   SHA:   <merge-sha>
   CI:    green (<duration>)
   Codex: <reaction or "disabled">
```

If anything weird happened during the flow (CI flaked, Codex didn't react, etc.), include a "Notes" section listing it so the user can decide whether to investigate.

---

## When NOT to use /ship

- **One-off shell commands** (`ls`, `git log`, `gh repo view`) — just run them.
- **Reading code / answering questions** — no PR needed.
- **Editing untracked / scratch files outside the repo root** — they're not in scope.
- **Emergency hotfix on broken `main`** — talk to the user first; the answer is usually "open a `fix/` branch and ship through this same flow", but the human needs to know `main` is broken.
