# mathlib4-fork-ops

Automation that keeps `DarcStar-Technologies/mathlib4` a healthy, cache-aligned
mirror of `leanprover-community/mathlib4`. Implements **P1.1/P1.2** of the fork
audit (`docs/darcstar/FORK_AUDIT_2026-07-16.md` in the fork).

This lives in its **own repo** on purpose: the fork's Actions are disabled
(P0), and the fork's `master` must stay a pure fast-forward mirror with zero
local commits — so the automation cannot live there.

## What it does (daily, 07:23 UTC, plus manual dispatch)

| Step | Check | Failure meaning |
|---|---|---|
| Guard | fork `master` has 0 local commits vs upstream | someone pushed to `master` — doctrine §4.1 violation; sync is **not** attempted |
| Sync | `merge-upstream` fast-forwards fork `master` | HTTP 409 = fork diverged; anything but `fast-forward`/`none` = investigate |
| Verify | `lakefile.lean`, `lean-toolchain`, `lake-manifest.json` blob-identical to upstream | any diff = **100% cache invalidation** — fix immediately |
| Probe (light, daily) | `lake exe cache get` on two probe modules, then `lake build --no-build` on them | upstream cache did not cover the probe cone — cache misalignment or upstream cache outage |
| Probe (deep: Mondays, toolchain-bump days, or `deep=true` dispatch) | full `lake exe cache get`, then `lake build --no-build` for all of Mathlib | some module isn't covered by cache — full alignment break |
| Alert | job failure → GitHub notifications; optional Slack webhook | — |

`lake build --no-build` exits nonzero if anything would need compiling, which is
exactly the property we want to assert: *a mirror never compiles*.

## Setup (one time, ~10 minutes)

1. **Create this repo** (private is fine — note private repos consume Actions
   minutes from the org quota; the daily light run is ~5–10 min, Monday deep
   runs ~30–60 min. Make it public if quota ever matters; nothing in here is
   sensitive):

   ```sh
   gh repo create DarcStar-Technologies/mathlib4-fork-ops --private \
     --description "Sync & cache-alignment automation for the mathlib4 fork" --clone
   cd mathlib4-fork-ops
   ```

2. **Copy the template** (from the fork's audit branch):

   ```sh
   mkdir -p .github/workflows
   B=https://raw.githubusercontent.com/DarcStar-Technologies/mathlib4/claude/fork-audit-improvements-2k5bhm/docs/darcstar/fork-ops-template
   curl -sSfo README.md "$B/README.md"
   curl -sSfo .github/workflows/sync-and-probe.yml "$B/.github/workflows/sync-and-probe.yml"
   git add -A && git commit -m "Add sync-and-probe automation" && git push
   ```

3. **Create the token**: GitHub → Settings → Developer settings →
   Fine-grained personal access tokens → Generate new token:
   - Resource owner: `DarcStar-Technologies`
   - Repository access: **Only select repositories** → `DarcStar-Technologies/mathlib4`
   - Permissions: **Contents: Read and write**, Metadata: Read (auto)
   - Expiration: 90 days (set a calendar reminder; the workflow fails loudly
     when the token dies, so expiry is annoying but not silent)

   Prefer a GitHub App / org service account over a personal PAT if the org
   has one — any credential that can `POST merge-upstream` on the fork works.

4. **Store secrets** in this repo:

   ```sh
   gh secret set FORK_SYNC_TOKEN -R DarcStar-Technologies/mathlib4-fork-ops   # paste the PAT
   gh secret set SLACK_WEBHOOK_URL -R DarcStar-Technologies/mathlib4-fork-ops # optional
   ```

5. **First run** (force the deep probe to baseline full cache coverage):

   ```sh
   gh workflow run sync-and-probe.yml -R DarcStar-Technologies/mathlib4-fork-ops -f deep=true
   gh run watch -R DarcStar-Technologies/mathlib4-fork-ops
   ```

## Acceptance (from the audit plan)

Seven consecutive green daily runs, including at least one toolchain-bump or
Monday deep run; a deliberately injected divergence (push any commit to a
throwaway branch of the fork, then to `master` of a *test* fork — do **not**
test on the real fork's master) trips the guard step.

## Failure runbook

- **Guard fails (`ahead_by != 0`)** — someone committed to fork `master`.
  Identify the commit; if it must be kept, it violates doctrine §4.1 — move it
  to a branch and hard-reset `master` to upstream
  (`git push --force-with-lease origin upstream/master:master` from a clone
  with both remotes). Then re-run.
- **Sync 409** — same as above but a conflicting file: restore the mirror.
- **Root-file mismatch** — the highest-severity alert. Find which of the three
  files differs and restore byte-parity with upstream immediately; every
  `cache get` on the fork is downloading nothing while this is broken.
- **Light probe fails, root files OK** — usually an upstream cache outage or a
  transient Azure error; re-run once. Persistent failure with `behind_by = 0`:
  check leanprover Zulip (#infrastructure) for cache incidents.
- **Deep probe fails on scattered modules** — upstream occasionally has brief
  windows where the newest master commit's cache is still uploading. Re-run in
  an hour; alert only if it persists.
- **Token expired/revoked** — guard step fails with 401. Rotate the PAT
  (setup step 3) and update `FORK_SYNC_TOKEN`.

## Invariants this repo enforces (doctrine §4)

1. Fork `master` = byte-identical fast-forward mirror of upstream `master`.
2. The three cache-root files are never modified on the fork.
3. The mirror never compiles: upstream's cache covers 100% of it.
