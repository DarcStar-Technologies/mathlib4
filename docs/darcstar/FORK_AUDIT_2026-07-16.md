# DarcStar-Technologies/mathlib4 — Fork Audit & Improvement Plan

**Date:** 2026-07-16 · **Fork HEAD audited:** `e4fd1ba` (synced same day; upstream was at `16274bd`)
**Method:** three-pass review — (1) source-level audit of the fork's build/CI/cache infrastructure, (2) web audit of upstream `leanprover-community/mathlib4` outstanding issues and PRs (perf / accuracy / stability), (3) adversarial review that fact-checked both passes against source and attacked every recommendation. Only findings that survived pass 3 appear in the plan; refuted items are documented in §5 so they are not re-proposed later.

---

## 0. Executive summary

- The fork is a **byte-identical public mirror** of upstream master: zero custom commits, zero PRs, issues disabled, all 48 upstream workflows active (created 2026-06-23, synced 2026-07-16).
- **One security finding (act now):** `.github/workflows/build_fork.yml` is the only unguarded `pull_request_target` workflow in the repo. It fires on any PR opened against this fork (the fork's `head.repo.fork == true` satisfies its condition), carries `id-token: write` / `pull-requests: write`, checks out and builds attacker-controlled code, and the repo accepts PRs from **anyone** (`pull_request_creation_policy: "all"`). It is inert today only because no runner matches its self-hosted `pr` label; it becomes remote code execution on org infrastructure the day a self-hosted runner is registered. Disable it in the Actions UI (do not delete — deletion causes recurring sync conflicts).
- **The economics that drive everything else:** upstream's binary cache is content-addressed and anonymously readable. A byte-identical mirror downloads a fully built 8,272-module library in minutes and **compiles nothing**. Any in-tree patch invalidates the patched file plus its entire downstream import cone (leaf file ≈ 1 module; mid-tree file ≈ thousands of modules ≈ multi-hour rebuilds, re-paid on essentially every sync). Touching any of `lakefile.lean`, `lean-toolchain`, `lake-manifest.json` invalidates **100%** of the cache.
- **Verdict on the fork (the "is it worth it" question):** keep the fork, but as a **mirror + upstream-contribution vehicle**, not a divergence vehicle. The "efficiency" thesis for in-tree patches is circular — a mirror pays no build time, so build-time optimizations patched into the fork can only save time the fork wouldn't have spent, while *creating* rebuild and conflict costs. Org efficiency is captured instead by (a) a downstream overlay Lake package that pins Mathlib (100% cache hits, unlimited org code, zero sync burden beyond a rev bump) and (b) routing mathlib improvements upstream through this fork, where they get benchmarking, bors validation, and permanent maintenance for free, then flow back into the mirror automatically **with cache included**. Under this posture the fork's carrying cost rounds to approximately zero.

---

## 1. Verified state of the fork

| Fact | Evidence |
|---|---|
| Public fork, Apache-2.0, created 2026-06-23, pushed 2026-07-16 | GitHub API (`private: false`, `created_at`, `pushed_at`) |
| Zero custom commits; single branch `master` = upstream `e4fd1ba` | git history; case-insensitive grep for "darcstar" matches nothing outside `.git/` |
| GitHub Issues disabled; PR creation open to all | GitHub API (`has_issues: false`, `pull_request_creation_policy: "all"`) |
| Actions enabled; scheduled workflows firing every 15–30 min and skipping (~220 junk "skipped" runs/day) | live Actions run list; `merge_conflicts.yml:5`, `dependent-issues.yml:5` (`*/15 * * * *`) |
| Main CI never runs here | `build.yml:34` guards on `github.repository == 'leanprover-community/mathlib4' \|\| …-nightly-testing` |
| Public repo ⇒ hosted-runner minutes and storage are **free** | GitHub pricing; kills every "CI cost in dollars" argument — remaining concerns are hygiene and security |
| Toolchain `leanprover/lean4:v4.33.0-rc1`; `fixedToolchain := true`, `platformIndependent := true` | `lean-toolchain`; `lakefile.lean:50-59` |
| CodeQL default setup enabled; CodeQL has no Lean extractor (scans only workflows/Python) | Actions run list; CodeQL language support |

### Cache mechanics (source-verified; the load-bearing facts)

- **Root hash** = hash of exactly three files — `lakefile.lean`, `lean-toolchain`, `lake-manifest.json` — plus a generation counter (`Cache/Hashing.lean:95-103`, `Cache/IO.lean:123`). Any byte changed in any of the three ⇒ every cache key changes ⇒ 100% invalidation.
- **Per-file key** = `hash(rootHash :: pathHash :: contentHash :: importHashes)`, recursive over the import graph (`Cache/Hashing.lean:114-154`). Patch a file ⇒ that file and its full transitive downstream cone miss the cache. Mathlib has **8,272** modules; mid-tree patches cost thousands of them.
- **Reads are anonymous and repo-agnostic**: the `master` container at `lakecache.blob.core.windows.net` is flat and hash-keyed (`Cache/Infra.lean:102-128`); a fork clone reads it with no credentials (`Infra.lean:155-165`). `lake exe cache get` works on this fork today.
- **Writes are upstream-privileged** (`MATHLIB_CACHE_AZURE_BEARER_TOKEN` / `MATHLIB_CACHE_SAS`, `Cache/Requests.lean:322-337`). A fork-owned cache is possible but **not layerable**: `MATHLIB_CACHE_GET_URL` replaces the entire read chain rather than adding a tier (`Requests.lean:302-304`); a real fork tier needs a fallback-proxying endpoint or a patch to `Cache/` (which doesn't invalidate module hashes but does create permanent sync conflicts).
- Every upstream master commit is bors-green with a published cache (single `publish_cache` producer, `build.yml:36-41`) — mirroring master is safe; there is no "master is broken" risk to hedge with tag-pinning **for the mirror** (tag-pinning remains right for downstream packages).

---

## 2. Upstream landscape (outstanding issues/PRs, as of 2026-07-16)

Scale: 277 open issues, 2,917 open PRs. No plain `performance` label exists; perf work is tracked via `performance-hack` (2 open), `slow-typeclass-synthesis` (17 PRs + tracking issue #16644), `longest-pole` (0 open — all merged), `large-import` (296 PRs), `awaiting-bench` (5 PRs), plus 54 open `perf(...)`-titled PRs.

### Performance
- **#16644** — typeclass-inference performance (master tracking issue; TC synthesis historically ~50% of build time). Most linked PRs are years-old, merge-conflicted hierarchy/priority refactors awaiting upstream consensus. *Not cherry-pickable.*
- **#26018 / #12737** — kernel-checking cost depends on universe-variable ordering (up to 29% per-file swings); root cause partly Lean core (lean4#5695). *Technique is real; apply it upstream, not in-tree (see §5.)*
- **#41705** (WIP, kbuzzard) — fixes 14 of the 20 slowest kernel-checked declarations, −141G instructions, proofs-only. *High value; arrives in the mirror automatically when merged. No action.*
- Active July-2026 perf PRs: #41703, #41753, #41761, #40347, #40723 — same: they arrive via sync.
- Benchmarking: every master commit is benched (VelCom / radar.lean-lang.org); `!bench` on PRs; ≥5% regressions reported to Zulip. A fork gets none of this — one more reason perf work belongs upstream.

### Accuracy
- No open mathlib soundness issues. Open tactic-correctness bugs: #741 (`zify` mis-uses `Eq.refl`), #8875 (`linarith` completeness regression), #15785 (`abel_nf` panic), #15865, #7657, #3426. None affect the validity of compiled mathlib; fixes arrive via sync.
- Linter gaps: #32257, #31840, #29041, #23905 (`countHeartbeats` broken — hampers perf measurement), #12096 (unimplemented `instance_priority` linter), **#20560** (silencing `docPrime` in downstream projects — directly relevant to our overlay package).
- Tech debt: #24212 (tracking; Tech Debt Bot metrics), **#31365** morphism-hierarchy refactor (active 2026-06) — a coming **large breaking refactor**; churn risk for any in-tree divergence and for our downstream package. Watch it.
- Deprecation policy: `@[deprecated]` with date; deletion allowed after ~6 months ⇒ downstream code has a ~6-month migration window per rename.

### Stability
- bors merge queue ⇒ master only advances on green batch builds; cache published per commit.
- Toolchain: Lean releases **monthly** (1–2 RCs each); mathlib bumps within days, staged via the separate `mathlib4-nightly-testing` repo. A mirror absorbs this for free (root files stay byte-identical after sync); a patched fork re-pays its whole patched cone on each bump.
- CI flakiness: essentially untracked on GitHub (one stale issue, #9410); triage happens on Zulip. Cache-mirror gap tracked in stale issue #6814 (partially superseded by `MATHLIB_CACHE_GET_URL` in-tree).
- Downstream advice (for the overlay package): pin release tags, upgrade stepwise through intermediate versions, always `lake exe cache get`.

---

## 3. Fork-side findings

1. **`build_fork.yml`** — unguarded `pull_request_target`, `id-token: write`, builds PR-head code, targets self-hosted label `pr` (`build_fork.yml:4,24-28,34,41`; `build_template.yml:54,65-67`). Latent RCE (see §0). All other `pull_request_target` workflows are repo-guarded to upstream (verified: `PR_summary.yml:16`, `add_label_from_diff.yaml:22`, `label_new_contributor.yml:20`, `check_pr_titles.yaml:18`, zulip emoji workflows).
2. **No CI runs on the fork at all** — `build.yml` skips here. Fine for a byte-identical mirror (upstream already verified every commit and published cache); a real gap the moment any patch lands.
3. **Actions noise** — ~220 skipped scheduled runs/day; unguarded-but-cheap `pre-commit.yml` (public repo ⇒ free; the pre-commit.ci Lite app isn't installed here, so it cannot push commits — earlier concern refuted) and `commit_verification.yml` (harmless artifact writes). Cosmetic, not financial.
4. **Hidden external runtime deps** — several workflows fetch scripts from `leanprover-community/mathlib-ci` at run time; the technical-debt metrics script is not in this repo.
5. **Privacy is foreclosed** — a fork of a public repo cannot be made private. Proprietary in-tree patches are impossible on this repo; that ambition would require a detached private mirror (losing fork-network PR ergonomics). This constrains strategy before any cost argument does.
6. **Committing anything to fork `master` ends fast-forward mirroring** (every sync becomes a merge commit). Harmless to the cache (content-addressed) but operationally noisier — hence the plan keeps `master` pure and drives automation from outside the repo. (This document lives on a side branch, not `master`, for exactly that reason.)

---

## 4. Doctrine (adopted policy — the part that outlives this document)

1. **Mirror stays byte-identical.** Fork `master` is a pure fast-forward mirror of upstream master. No commits to `master`, ever.
2. **The three root files are untouchable** (`lakefile.lean`, `lean-toolchain`, `lake-manifest.json`): any change costs 100% of the cache.
3. **Overlay-first.** All org-authored Lean code (lemmas, tactics, automation, experiments) lives in a separate downstream Lake package that requires Mathlib at a pinned rev. Zero cache invalidation, zero sync burden beyond rev bumps, and it can be private.
4. **Upstream-first for improvements to mathlib itself.** Perf/accuracy work (universe reordering, simp squeezing, priority fixes, proof speedups) is contributed upstream via branches on this fork — gaining `!bench`, bors, review, and permanent maintenance — and returns through the mirror with cache.
5. **In-tree patch bar** — carry a patch on the fork only when **all** hold: (a) upstream rejected it or is realistically >3 months from merging; (b) the benefit accrues to org workloads, not to mathlib build times the mirror never pays; (c) its downstream cone is small (order hundreds of modules, not thousands); (d) a named engineer owns the weekly sync-and-rebuild. *Today zero candidates meet this bar.*
6. **Workflow changes on the fork are UI-disables, never file deletions** (deletions conflict on every sync of upstream's constantly-churning CI files).

---

## 5. Adversarial review — what changed (so it doesn't get re-proposed)

| Original candidate | Verdict | Why |
|---|---|---|
| Neutralize `build_fork.yml` | **KEPT, upgraded to security-critical** | Unguarded `pull_request_target` + open PR policy + future self-hosted runners = RCE; "it's inert" fails as an objection |
| Fork-native full CI workflow | **DEMOTED, merged into sync probe** | On a byte-identical mirror, `cache get` + `lake build` is a no-op re-verification of what bors already verified — a smoke test, not CI |
| Automated upstream sync | **KEPT — highest-value operational item** | Manual sync silently stops happening; cache alignment is the fork's most valuable property |
| Root-file / leaf-ward / overlay policy | **KEPT — best single item** | Evidence airtight; nearly free; the decision most likely to be gotten wrong first |
| Prune workflows for "CI cost" | **MODIFIED** | Repo is public ⇒ free; the honest options are UI-disable the noisy set or disable Actions repo-wide |
| `pre-commit.yml` "burns money, force-pushes" | **REFUTED** | Free on public repos; the Lite app that would push fixes isn't installed on the fork |
| Fork-owned cache tier | **DEFERRED, effort raised to L** | `MATHLIB_CACHE_GET_URL` is all-or-nothing; layering needs a proxy or `Cache/` patch; no workload justifies it yet |
| Recurring fork health/debt reports | **KILLED (for now)** | On an identical tree they reproduce numbers upstream already publishes; re-point bench at the overlay package later |
| Cherry-pick #41705 etc. "once merged" | **REFUTED** | Merged PRs arrive automatically via the mirror; pre-merge cherry-picks buy cone rebuilds + guaranteed conflicts |
| Apply universe/simp/priority optimizations in-tree | **REFUTED — counterproductive** | A mirror compiles nothing; these edits *create* the build time they claim to save, plus permanent conflict debt. Do them upstream |
| Implement #6814 cache-mirror env var | **REFUTED as moot** | `MATHLIB_CACHE_GET_URL` / `MATHLIB_CACHE_FROM` already exist in-tree; the real gap is layered reads (different, larger task) |
| "Pin release tags" posture | **RECONCILED** | Mirror tracks master (every commit bors-green + cached); the *overlay package* pins tags/SHAs |

---

## 6. Implementation plan (scoped items)

### P0 — this week (~1 hour total, all reversible)

**P0.1 — Disable `build_fork.yml` in the Actions UI.** *Security. Effort: minutes. Risk: none* (workflow is useless on the fork; UI-disable produces no sync diff). Acceptance: workflow shows "disabled" in Actions; a test PR against the fork triggers no `build_fork` run.

**P0.2 — Choose the Actions posture (recommended: disable Actions repo-wide).** For a pure externally-synced mirror this achieves all pruning goals and most of P0.1's mitigation in one setting; re-enable selectively if the fork acquires a real workload. Fallback if org policy wants Actions on: UI-disable the two 15-minute crons, hourly `update_dependencies.yml`, `pre-commit.yml`, `commit_verification*.yml`, and the zulip/bors/nightly/labeling families; keep `actionlint.yml`. *Hygiene/security-hardening. Effort: minutes–1h. Risk: none.* Acceptance: junk "skipped" runs stop appearing.

**P0.3 — Ratify §4 doctrine** as org policy (this document, or the ops repo README). *Effort: review-only.*

### P1 — weeks 1–2 (the durable machinery)

**P1.1 — External sync-and-probe automation.** A tiny separate org repo (`mathlib4-fork-ops`) with a daily cron that: (1) fast-forwards fork `master` via GitHub's sync-fork API (keeps the mirror pure); (2) clones/updates, verifies the three root files are byte-identical to upstream (`git diff upstream/master -- lakefile.lean lean-toolchain lake-manifest.json` must be empty); (3) runs `lake exe cache get` as a smoke test and reports hit rate; (4) on days `lean-toolchain` changed, runs a deeper `lake build` probe; (5) alerts (Slack/email) on sync failure, divergence, or cache misses. *Stability. Effort: M (1–3 days). Risk: low.* Acceptance: seven consecutive green daily runs including one toolchain-bump day; a deliberately-injected root-file diff triggers the alert.

**P1.2 — Root-file guard check.** Part of P1.1's probe (or a required check if fork PRs are ever used for internal work): fail loudly if a branch modifies the three root files. *Perf(cache)/policy enforcement. Effort: S.*

### P2 — weeks 2–4 (where the efficiency actually lives)

**P2.1 — Stand up the downstream overlay package** (separate repo, can be private): Lake project requiring `mathlib` pinned to a release tag or specific synced SHA; CI = `lake exe cache get` + `lake build` (minutes); this is the home for all org lemmas/tactics/automation. Include the stepwise-upgrade rule (never skip intermediate mathlib versions) and a monthly rev-bump routine aligned to mathlib's monthly toolchain cadence, with the ~6-month deprecation window as the migration budget. *Perf + stability + (optionally) privacy. Effort: M. Risk: low.* Acceptance: package builds green in CI using upstream cache; one real org lemma lives in it.

**P2.2 — Upstream contribution pipeline.** Document and dry-run the flow: branch on this fork → PR to upstream (fork branches get full upstream CI + `forks`-container cache, paid by leanprover-community) → merged work returns via the mirror. First candidates if the org wants perf wins: universe-variable reordering in hot files (#26018/#12737 technique), simp squeezing (#19751 technique) — each validated by upstream `!bench`. Note upstream's LLM policy: AI-assisted PRs must disclose tooling and will be labeled `LLM-generated`. *Accuracy/perf, delivered upstream. Effort: S to set up; ongoing per-PR.* Acceptance: one small PR through the full loop.

**P2.3 — Upstream watchlist (quarterly, 30 min):** #41705 (kernel-check perf, WIP), #16644 (TC inference), #26018 (universe ordering / lean4#5695), **#31365 (morphism-hierarchy refactor — breaking-churn early warning for the overlay package)**, #24212 (tech-debt metrics), #20560 (`docPrime` silencing for downstream — affects our overlay), monthly toolchain releases. *Effort: S recurring.*

### P3 — deferred, with explicit triggers (do NOT build now)

**P3.1 — Fork-owned cache tier** (own Azure/S3 endpoint + fallback proxy or `Cache/` patch). *Trigger:* an in-tree patch passes the §4.5 bar AND its cone rebuild exceeds ~30 min AND multiple engineers/CI pay it repeatedly. *Effort: L. Risk: medium (cache-poisoning surface — see `Cache/SECURITY.md`).*

**P3.2 — Bench infrastructure** (`scripts/bench/` radar-compatible suite) pointed at the **overlay package's** hot modules, not at mathlib. *Trigger:* overlay package accumulates perf-sensitive org code.*

**P3.3 — Private detached mirror.** *Trigger:* a genuine need for proprietary in-tree mathlib patches (currently none; note this public fork can never be private).*

### Explicitly rejected (see §5)
Pre-merge cherry-picks of upstream PRs; in-tree universe/simp/priority optimization patches; fork-side re-implementation of upstream tactic bug fixes; deleting workflow files; full fork CI while the mirror is byte-identical; implementing #6814 (superseded in-tree).

---

## 7. The cost-benefit answer

**Question asked:** "this may increase cost burden of maintaining a fork, but I think the efficiency is worth it."

**Answer:** the fork is worth keeping — at roughly zero carrying cost — but only under the §4 doctrine. The efficiency you're after does not come from maintaining divergence on the fork; it comes from *not* diverging:

- **What the mirror buys:** an org-controlled pin of mathlib (insurance against upstream incidents), minutes-to-full-build via upstream's anonymous cache on every synced commit, and the standard vehicle for contributing upstream (upstream CIs and benches your fork branches at their expense).
- **What divergence costs:** a mid-tree patch invalidates up to most of 8,272 modules (multi-hour rebuild) and re-pays that cone on essentially every daily sync where upstream touched its ancestry — plausibly tens of compute-hours per month plus standing conflict-resolution engineering, with no bench bot, no bors, no layered cache, and (because the fork is public) no possibility of keeping such patches proprietary anyway.
- **Where org efficiency actually compounds:** the overlay package (P2.1) captures 100% of upstream's cache while hosting unlimited org code, and upstream contributions (P2.2) convert your improvements into permanently-maintained, benchmarked, cache-published mathlib — which your mirror then receives for free.

If, later, a specific patch genuinely clears the §4.5 bar, the P3 items describe exactly what to build and what it will cost — that is the point at which "fork maintenance burden" becomes real, and it should be accepted deliberately, per patch, not as a posture.
