# P0 Runbook — Fork Hardening (from FORK_AUDT 2026-07-16, §6 P0)

Two of the three P0 items are repository **admin settings** that must be flipped in the
GitHub UI or with an admin-scoped `gh` token; they cannot be done by committing files
(and per doctrine §4.1/§4.6, must not be). Each item below gives the UI path and the
equivalent `gh` CLI command, plus the acceptance check.

All actions here are instantly reversible and produce **no commits**, so they never
affect upstream sync or cache alignment.

---

## P0.1 — Disable `build_fork.yml` (security-critical)

Why: the only unguarded `pull_request_target` workflow in the repo; fires on any PR
opened against this fork (PR creation is open to everyone), builds attacker-controlled
code with `id-token: write`. Latent RCE the day a self-hosted runner labeled `pr`
is registered.

> **Verified 2026-07-16:** `build_fork.yml` is **not yet registered** as a workflow on
> the fork (GitHub registers `pull_request_target` workflows lazily, on first trigger;
> no PR has ever been opened against this repo — API lookup 404s and it is absent from
> all 48 registered workflows). Consequence: it **cannot be individually disabled yet**,
> in the UI or via API. Until it registers, the only effective mitigations are
> P0.2 Option A (disable Actions repo-wide — recommended) or, if Actions must stay on,
> disabling it the moment it appears (it registers on the first PR; the job itself
> merely queues against the nonexistent `pr` runner label, so there is a window to act
> before any self-hosted runner exists).

**UI (once registered):** repo → *Actions* tab → left sidebar →
**"continuous integration (mathlib forks)"** → `…` menu (top right) → **Disable workflow**.

**CLI (once registered):**
```sh
gh workflow disable build_fork.yml -R DarcStar-Technologies/mathlib4
# or, equivalently:
gh api -X PUT repos/DarcStar-Technologies/mathlib4/actions/workflows/build_fork.yml/disable
```

**Acceptance:** `gh workflow list -R DarcStar-Technologies/mathlib4 --all | grep build_fork`
shows `disabled_manually`; a test PR triggers no "continuous integration (mathlib forks)" run.
Also unregistered today (same lazy-registration reason, same handling): `bors.yml`,
`ci_dev.yml`, `bot_fix_style.yaml`, `labels_from_comment.yml`, `splice_bot.yaml`,
`splice_bot_wf_run.yaml`, `sync_closed_tasks.yaml`, `label_new_contributor.yml`.

> Do **not** delete or edit the file: upstream edits it regularly and any in-tree change
> creates recurring sync conflicts (doctrine §4.6). The disabled state lives in repo
> settings and survives syncs. Caveat: GitHub re-enables a manually-disabled workflow
> if a later push modifies that workflow file — so after any sync where upstream touched
> `build_fork.yml`, re-check the acceptance command above. (The P1.1 sync automation
> will do this check automatically; option A below removes the concern entirely.)

---

## P0.2 — Actions posture

**Option A (recommended — and currently the only complete fix): disable Actions repo-wide.**
The fork is a pure mirror; sync automation will live outside the repo (P1.1). This one
setting kills all ~220 junk skipped runs/day, neutralizes every inherited workflow —
including the not-yet-registered `build_fork.yml`, which nothing else can disable today
(see P0.1) — and is one click to revert.

**UI:** repo → *Settings* → *Actions* → *General* → **Actions permissions** →
select **"Disable actions"** → Save.

**CLI:**
```sh
gh api -X PUT repos/DarcStar-Technologies/mathlib4/actions/permissions \
  -F enabled=false
```

**Acceptance:** Actions tab shows workflows disabled; no new workflow runs appear after
the next 15-minute cron boundary.

**Option B (fallback, if org policy requires Actions to stay on):** individually disable
every workflow except the two cheap, useful linters (`actionlint.yml`,
`validate_mathlib_ci_paths.yml`):

```sh
R=DarcStar-Technologies/mathlib4
gh workflow list -R "$R" --all --limit 100 --json id,path \
  | jq -r '.[] | select(.path | test("actionlint|validate_mathlib_ci_paths") | not) | .id' \
  | while read -r id; do
      gh api -X PUT "repos/$R/actions/workflows/$id/disable" && echo "disabled $id"
    done
```

**Acceptance:** `gh workflow list -R "$R" --all --json path,state | jq -r '.[] | "\(.state)\t\(.path)"' | sort`
shows every workflow `disabled_manually` except the two keepers; junk runs stop.

> Same caveat as P0.1: a sync that modifies a manually-disabled workflow file re-enables
> it. Option B therefore needs the P1.1 probe to re-assert disables after each sync;
> Option A does not.

Optional either way: *Settings* → *Advanced Security* → disable **CodeQL default setup**
(it cannot analyze Lean; it only scans workflows and `scripts/` Python — keep it if that
marginal workflow-scanning value is wanted, kill it for quiet; immaterial either way).

---

## P0.3 — Ratify the doctrine

Review and adopt §4 of `docs/darcstar/FORK_AUDIT_2026-07-16.md` as org policy:

1. Fork `master` stays a byte-identical fast-forward mirror — no commits, ever.
2. `lakefile.lean` / `lean-toolchain` / `lake-manifest.json` are untouchable (any change = 100% cache loss).
3. Org Lean code lives in a downstream overlay package, not in-tree.
4. Improvements to mathlib itself go upstream via fork branches.
5. In-tree patches only past the four-condition bar (§4.5) — currently met by nothing.
6. Workflow changes on the fork are UI-disables, never file edits/deletions.

Acceptance: whoever owns the fork signs off (a one-line ack in the ops channel or on the
audit PR is enough), and the doctrine is linked from the org's engineering docs.

---

## After the switches are flipped

Reply in the session (or re-run the acceptance commands) and the audit session will
verify workflow states via the API and mark P0 complete; next up is P1.1
(external sync-and-probe repo).
