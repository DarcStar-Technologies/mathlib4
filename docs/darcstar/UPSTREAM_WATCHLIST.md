# Upstream watchlist (P2.3) — review quarterly, ~30 minutes

Check each item; the "act when" column says what movement means for us.
Baseline date: 2026-07-16 (fork audit). Update the notes column each pass.

| Item | What it is | Why we care | Act when |
|---|---|---|---|
| [#41705](https://github.com/leanprover-community/mathlib4/pull/41705) | perf: speed up kernel typechecking of slowest declarations (WIP) | −141G instructions across the library; arrives via mirror when merged | Merged → nothing to do (verify it's in the mirror); Closed-unmerged → note technique for upstream contributions |
| [#16644](https://github.com/leanprover-community/mathlib4/issues/16644) | Typeclass-inference performance tracking issue | TC synthesis ≈ half of mathlib build time; any structural fix changes library-wide perf | A linked hierarchy PR merges → expect churn in overlay bump; re-read audit §2 |
| [#26018](https://github.com/leanprover-community/mathlib4/issues/26018) / lean4#5695 | Kernel perf depends on universe-variable ordering (root cause partly Lean core) | Source of our best upstream-contribution candidates; core fix would obsolete manual reordering | Core fix lands → stop universe-reordering contributions |
| [#31365](https://github.com/leanprover-community/mathlib4/issues/31365) | Morphism-hierarchy refactor (tech debt, active) | Large breaking refactor → biggest known churn risk for overlay code | Refactor PRs start merging → schedule extra overlay-bump time; pin to the release tag *before* the refactor until org code is migrated |
| [#24212](https://github.com/leanprover-community/mathlib4/issues/24212) | Tech-debt tracking (bot-counted metrics) | Signals where upstream wants cleanup PRs — easy contribution surface | Standing: pick items matching team skills |
| [#20560](https://github.com/leanprover-community/mathlib4/issues/20560) | Silencing `docPrime` (and similar) linters downstream | Affects our overlay directly if org names trip mathlib-inherited linters | Resolution merges → adopt the sanctioned silencing mechanism in overlay |
| [#13864](https://github.com/leanprover-community/mathlib4/issues/13864) | `measurability` → `fun_prop` migration | Tactic swap that can break/slow overlay proofs using `measurability` | Migration completes → sweep overlay for `measurability` uses |
| [Lean releases](https://github.com/leanprover/lean4/releases) | Monthly toolchain cadence (1–2 RCs each) | Each mathlib toolchain bump flows into overlay via `lake update mathlib` | Monthly: bump the overlay within the release month; never skip versions |
| [Mathlib releases](https://github.com/leanprover-community/mathlib4/releases) | Version tags matching Lean releases | Stepwise-upgrade waypoints for the overlay | Use as pins if the team prefers tags over synced SHAs |
| Fork-ops runs | Our own sync-and-probe history | 7 consecutive green dailies = P1 acceptance; failures = cache/doctrine incidents | Any red run → follow the runbook in mathlib4-fork-ops README |

Also each pass: skim open `perf`-titled upstream PRs
([query](https://github.com/leanprover-community/mathlib4/pulls?q=is%3Apr+is%3Aopen+perf+in%3Atitle))
for techniques worth contributing, and confirm the deprecation clock isn't about
to delete anything the overlay still uses (`lake build` warnings during bumps
are the early signal).
