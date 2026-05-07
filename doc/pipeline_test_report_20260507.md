# Pipeline test report — 2026-05-07

> First end-to-end exercise of the Cursor-agent → CI → squash-merge pipeline on
> `xidikr/TEST`, performed during the bootstrap session per
> `agent_pipeline_onboarding_for_teammate.md` § 14.

---

## Decisions chosen at onboarding (§ 3)

| # | Question | Choice | Rationale |
|---|---|---|---|
| Q1 | Network for git/SSH | **A** SSH-over-443 | Owner is in China; port 22 typically blocked. |
| Q2 | SSH key strategy | **A** new ed25519 dedicated to GitHub | Existing `~/.ssh/id_rsa` (RSA) was reserved for other services; new key isolates GitHub auth. |
| Q3 | Repo provenance | **A** brand-new empty GitHub repo | `xidikr/TEST` was created Public on the web. |
| Q4 | Tech stack | **F** mixed C++ + Python | `verify.sh` auto-detects each toolchain and skips when not present. |
| Q5 | Branch protection strictness | **B** PR + CI green, 0 approvals | Solo developer; requiring approvals would deadlock since author cannot approve own PR. |
| Q6 | ChatGPT Codex auto-review | **B** disabled | No active ChatGPT Plus subscription required for this run. |
| Q7 | First demo PR | **C** doc-only edit | Pure pipeline smoke test, no functional code yet. |

---

## Hosts & versions

| Component | Version |
|---|---|
| OS | Linux 6.8.0-110-generic x86_64 |
| git | 2.34.1 |
| gh CLI | 2.92.0 (installed to `~/.local/bin/gh`, no `sudo` used) |
| OpenSSH | system default; verified via `ssh -T git@github.com` |
| GitHub Actions runner | `ubuntu-latest` (provided by GitHub-hosted) |

---

## Configuration written to disk

### Local user-scope (machine-wide, additive)

| File | Change |
|---|---|
| `~/.ssh/config` | Created from scratch. Single block: `Host github.com → ssh.github.com:443`, `IdentityFile ~/.ssh/id_ed25519_github`, `IdentitiesOnly yes`. |
| `~/.ssh/id_ed25519_github` / `.pub` | New ed25519 keypair, comment `1710318115@qq.com`, no passphrase. Public key uploaded to https://github.com/settings/keys with title `lenovo-cursor`. |
| `~/.ssh/known_hosts` | Appended `[ssh.github.com]:443` host keys for RSA / ECDSA / Ed25519 via `ssh-keyscan -p 443`. |
| `~/.local/bin/gh` | gh CLI 2.92.0 binary copied from upstream release tarball; `chmod +x`. |
| `~/.config/gh/hosts.yml` | Created by `gh auth login --hostname github.com --git-protocol ssh --web`. |
| `~/.gitconfig` (global) | Added `credential.https://github.com.helper = !/home/lenovo/.local/bin/gh auth git-credential` via `gh auth setup-git`. **Side-effect of `gh auth setup-git`**, used to coexist with the pre-existing global `url.https://github.com/.insteadof = git@github.com:` rewrite. Disclosed to owner. |

### Repo-scope (`/home/lenovo/桌面/test/.git/config`)

| Key | Value | Reason |
|---|---|---|
| `user.name` | `xidikr` | Repo-local identity to avoid touching global `~/.gitconfig`. |
| `user.email` | `1710318115@qq.com` | Same reason. |
| `remote.origin.url` | `https://github.com/xidikr/TEST.git` (fetch) | Compatible with the global `insteadof` rewrite + gh credential helper. |
| `url.git@github.com:.pushInsteadOf` | `https://github.com/` | **Force pushes back to SSH** so they go via `ssh.github.com:443` using the ed25519 key, even though the stored remote URL is HTTPS. Without this, pushes would attempt HTTPS and rely on the credential helper. |

### Repo-scope files created (committed in PR #1)

| Path | Lines | Purpose |
|---|---|---|
| `AGENTS.md` | 165 | Operating manual + P0/P1/P2/P3 review classification. |
| `scripts/verify.sh` | 122 (`100755`) | Local + CI single source of truth; mixed-stack auto-detect. |
| `.github/workflows/ci.yml` | 51 | CI ending in `bash ./scripts/verify.sh`; job name `build`. |
| `.github/PULL_REQUEST_TEMPLATE.md` | 17 | 4-section PR body template. |
| `.cursor/rules/00-workflow.mdc` | 51 | `alwaysApply` workflow rules. |
| `.cursor/commands/ship.md` | 165 | `/ship` 11-step canonical procedure. |
| `.gitignore` | 106 | Python + C++ + editor + secret patterns. |

---

## GitHub web settings (§ 5)

| Setting | URL | Final state |
|---|---|---|
| Allow auto-merge | `…/settings` Pull Requests | ✅ enabled |
| Automatically delete head branches | `…/settings` Pull Requests | ✅ enabled |
| Branch protection rule on `main` | `…/settings/branches` (classic) | ✅ created, see below |
| Actions permissions | `…/settings/actions` | `Allow all actions and reusable workflows` |

### Branch protection on `main` (verified via `gh api`)

```text
required_status_checks.contexts                 = ['build']
required_status_checks.strict (up-to-date)      = True
enforce_admins.enabled                          = True
required_pull_request_reviews                   = present
  required_approving_review_count               = 0   ← matches Q5 = B (lowered from default 1 via API; web UI minimum was 1)
allow_force_pushes                              = False
allow_deletions                                 = False
```

**Notable correction during setup**: GitHub's classic UI dropdown for "Required approvals" only offers 1-6, no 0 option. Initial save resulted in `count = 1`, which would have deadlocked solo workflow (author cannot approve own PR). Lowered to `0` via:

```bash
gh api repos/xidikr/TEST/branches/main/protection/required_pull_request_reviews \
  -X PATCH -F required_approving_review_count=0
```

---

## End-to-end runs

### Run 1 — bootstrap PR #1 (no protection yet, expected to merge immediately)

| Stage | Timestamp (UTC) | Detail |
|---|---|---|
| PR opened | 2026-05-07 09:00:30 | https://github.com/xidikr/TEST/pull/1 |
| CI `build` (PR run) | 09:00:30 → 09:00:46 (~16s) | Pass |
| Squash-merged | 2026-05-07 09:00:43 | Merge SHA `045c7f0` |
| CI `build` (push run on main) | 09:00:46 → 09:01:02 (~16s) | Pass |
| Local cleanup | 09:01 | `main` FF'd to `045c7f0`; head branch auto-deleted on remote. |

**Verdict**: As expected. With no branch protection, the PR was directly squash-merged via `gh pr merge --squash --delete-branch` (not auto-merge). CI ran for visibility but did not gate the merge.

### Run 2 — demo PR #2 (full protection in place)

| Stage | Timestamp (UTC) | Detail |
|---|---|---|
| Branch created | 2026-05-07 09:27 | `docs/pipeline-smoke-test` off `main`. |
| Local `verify.sh` | 09:27 | `ALL GREEN` (toolchain steps SKIP'd; sanity + secret checks pass). |
| Push | 09:27 | Single commit; pushed via SSH-over-443 (confirmed via `pushInsteadOf` resolving to `git@github.com:`). |
| PR opened (REST API) | 09:28:04 | https://github.com/xidikr/TEST/pull/2; head SHA `1603471112…`. |
| Auto-merge enabled | 09:28:04 | `gh pr merge 2 --squash --auto --delete-branch`. `mergeStateStatus = BLOCKED`, `mergeable = MERGEABLE`. |
| CI `build` started | 09:28:14 | `IN_PROGRESS`. |
| CI `build` passed | ~09:28:19 (~5s) | `conclusion = success`. |
| Auto-merge fired | 09:28:21 | `state = MERGED`, merge SHA `d4a7f9f`, head branch auto-deleted. |
| Local cleanup | 09:28:30 | `git pull --ff-only` (FF to `d4a7f9f`); `origin/docs/pipeline-smoke-test` pruned. |

**Total elapsed (PR open → merged)**: ~17 seconds.

**Verdict**: Branch protection holds the merge. Auto-merge fires automatically once CI is green and protection conditions are satisfied. Head branch is auto-deleted. Squash merge applied.

---

## Definition-of-Done check (§ 7 of onboarding)

- [x] `ssh -T git@github.com` returns `Hi xidikr!`
- [x] `gh auth status` shows logged in (account `xidikr`, ssh protocol, scopes `repo, read:org, gist`)
- [x] `git remote -v` shows correct origin (`fetch=https`, `push=ssh via pushInsteadOf`)
- [x] `bash scripts/verify.sh` passes locally (`ALL GREEN`)
- [x] `.github/workflows/ci.yml` ends in `bash ./scripts/verify.sh`
- [x] `AGENTS.md` contains P0 / P1 / P2 / P3 review guidelines
- [x] `.cursor/rules/00-workflow.mdc` and `.cursor/commands/ship.md` in place
- [x] **Bootstrap PR (#1) merged** to `main`
- [x] `gh api repos/xidikr/TEST/branches/main/protection` returns `contexts: ['build']` and `enforce_admins: True`
- [x] **Demo PR (#2) merged** end-to-end (CI gated, auto-merge fired, branch auto-deleted)
- [N/A] Codex reaction on demo PR — Codex is intentionally disabled (Q6 = B).
- [x] `doc/pipeline_test_report_20260507.md` written (this file).

---

## Known caveats / follow-ups

1. **`verify.sh` is currently a no-op** for both C++ and Python steps because the repo has no `CMakeLists.txt` / `pyproject.toml` yet. When real code lands, those steps will start exercising real builds; if the new code's failure mode is "passes verify but doesn't actually compile", consult onboarding 坑 #8.
2. **Solo workflow assumption**: branch protection is configured for `required_approving_review_count = 0` because there is only one collaborator. If a second collaborator joins and the policy should tighten, re-run the API call with `count = 1` and add a Codex enable step (§ 6 of onboarding doc) to provide the second-pair-of-eyes role.
3. **Codex disabled**: enabling later requires the steps in `agent_pipeline_onboarding_for_teammate.md` § 6 (install ChatGPT Codex Connector GitHub App, toggle auto-review for `xidikr/TEST` at https://chatgpt.com/codex/settings/code-review). No code changes needed in this repo to switch it on.
4. **Global `~/.gitconfig` was modified once** (by `gh auth setup-git` during onboarding). The owner was informed; the helper line can be removed any time with `git config --global --unset credential.https://github.com.helper`.

---

**Pipeline status: green. Day-to-day usage starts with `/ship <one-sentence change>` in Cursor chat.**
