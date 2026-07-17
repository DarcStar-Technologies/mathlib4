# DarcstarLean

DarcStar Technologies' Lean 4 library, built **on top of** mathlib — the overlay
package from the fork audit (`docs/darcstar/FORK_AUDIT_2026-07-16.md`, item P2.1).

**Why this repo exists (doctrine §4.3):** all org-authored Lean code lives here,
*not* as patches inside the mathlib fork. Because mathlib is consumed as a pinned
dependency, upstream's binary cache covers 100% of it — `lake exe cache get`
delivers ~8,300 prebuilt modules in minutes and only this package's own files
ever compile. In-tree fork patches would instead invalidate the cache for every
downstream module they touch. This repo can be private; the mirror can't.

## Layout

- `lakefile.toml` — requires `mathlib` from the DarcStar mirror at a pinned SHA.
  The pin is a bors-green upstream master commit (the mirror is byte-identical),
  so upstream's cache applies.
- `lake-manifest.json` — locked transitive deps, copied from mathlib's manifest
  at the pinned rev (regenerate any time with `lake update mathlib`).
- `lean-toolchain` — must match the pinned mathlib's toolchain; `lake update
  mathlib` maintains this automatically via mathlib's post-update hook.
- `DarcstarLean/` — org modules. Add an `import DarcstarLean.<New>` line to
  `DarcstarLean.lean` for each new module so `lake build` covers everything.

## Setup (one time)

```sh
gh repo create DarcStar-Technologies/darcstar-lean --private \
  --description "DarcStar Lean library on mathlib (overlay package)" --clone
cd darcstar-lean
# copy this template's files in (same curl pattern as the fork-ops setup), then:
git add -A && git commit -m "Scaffold overlay package" && git push
```

The first CI run is the acceptance test: it must complete in well under 45
minutes, with the `Get mathlib cache` step succeeding and `lake build` compiling
only `DarcstarLean.*` modules.

## Local development

```sh
curl -sSfL https://elan.lean-lang.org/elan-init.sh | sh -s -- -y --default-toolchain none
lake exe cache get   # minutes: downloads prebuilt mathlib
lake build           # seconds: compiles only org code
```

Never run a bare `lake build` before `cache get` on a fresh clone — that is the
multi-hour full compile the cache exists to avoid.

## Bumping mathlib (monthly routine, or as needed)

1. Pick the new pin: the mirror's current synced `master` SHA (the fork-ops
   sync workflow keeps it equal to upstream), or a mathlib release tag.
2. Edit `rev` in `lakefile.toml`.
3. `lake update mathlib` — rewrites `lake-manifest.json` and `lean-toolchain`.
4. `lake exe cache get && lake build`; fix any breakage from upstream renames.
5. Commit all changed files together.

Rules of thumb from the audit:
- **Upgrade stepwise.** If jumping several mathlib versions, go through the
  intermediate release tags one at a time (upstream's own guidance) rather than
  straight to latest.
- **Budget:** deprecated mathlib declarations are deleted ~6 months after
  deprecation — a monthly bump keeps migration diffs small and warnings visible
  while the old names still exist.
- **Churn watch:** before a bump, skim `UPSTREAM_WATCHLIST.md` (in the audit
  docs) — in particular the morphism-hierarchy refactor (mathlib4 #31365),
  which will be a large breaking change when it lands.
- If a style linter complains about downstream naming (e.g. `docPrime`), see
  mathlib4 #20560 for the silencing options before renaming org declarations.

## What does NOT go here

Changes to mathlib itself (perf fixes, lemma generalizations, bug fixes) —
those go upstream via the fork, per `UPSTREAM_CONTRIBUTION.md`. Merged upstream
work reaches this repo through the normal monthly bump, prebuilt.
