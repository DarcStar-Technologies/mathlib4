# Contributing to mathlib through the DarcStar fork (P2.2)

Doctrine §4.4: improvements to mathlib itself — performance fixes, lemma
generalizations, tactic bug fixes — are contributed **upstream**, using this fork
as the vehicle. Upstream runs its full CI, benchmarking, and review on the PR at
its own expense; the merged result returns to our mirror automatically, with
binary cache included. Nothing is carried in-tree here.

## The loop

1. **Branch off the mirror.** From a clone of `DarcStar-Technologies/mathlib4`:
   `git switch -c <topic> origin/master`. Never commit to `master` (doctrine §4.1;
   the fork-ops guard will fail the daily sync if anyone does).
2. **Develop with the cache.** `lake exe cache get` first; after editing file X,
   only X and its downstream cone recompile locally.
3. **Push the branch to the fork**, then open a PR with
   **base = `leanprover-community/mathlib4:master`**, head =
   `DarcStar-Technologies:<topic>`.
4. **Upstream CI takes over.** PRs from org forks are first-class upstream: their
   `build_fork.yml` builds fork PRs on upstream runners and uploads the branch's
   cache to their `forks` container. Our fork's disabled Actions are irrelevant —
   PR workflows run in the *base* repo's context.
5. **Review → bors.** A maintainer (or delegate) sends the PR to the bors queue;
   it merges only after a green batch build.
6. **It comes back for free.** The next daily fork-ops sync brings the merged
   commit into our mirror; the next overlay `lake update mathlib` bump delivers
   it to org code, prebuilt.

## Upstream conventions that matter

- **PR titles**: `feat(Topic/Path): …`, `fix:`, `perf:`, `chore:`, `doc:` —
  enforced by upstream tooling; one topic per PR; keep diffs small.
- **Deprecations**: renames/removals of public declarations need `@[deprecated]`
  aliases with a date.
- **Perf claims need `!bench`**: comment `!bench` on the PR to run upstream's
  benchmark suite; a perf PR without bench numbers will stall. This is exactly
  the validation a fork cannot run itself — the reason perf work goes upstream.
- **AI disclosure (required)**: LLM-assisted contributions must disclose the
  tooling used in the PR description and will carry the `LLM-generated` label.
  Low-effort LLM PRs are summarily closed — a human must fully understand and
  stand behind every line. Budget real review time before submitting.
- **Zulip first for anything non-obvious**: for refactors or API changes, float
  the idea on leanprover.zulipchat.com (#mathlib4) before writing code.

## Dry-run checklist (first PR)

Start with something trivially reviewable — a docstring fix, a typo, a missing
`@[simp]` justified on Zulip — to exercise the loop end-to-end before
attempting substantive work:

- [ ] Branch from current mirror master, cache get, edit, build the touched cone
- [ ] `lake exe lint-style` clean on touched files; commit message = PR title style
- [ ] Push branch to fork; open PR against upstream master
- [ ] Confirm upstream CI runs on the PR (build + lint jobs appear)
- [ ] Respond to review; maintainer merges via bors
- [ ] Confirm the commit appears in the mirror after the next daily sync
- [ ] Delete the topic branch from the fork

## Candidate work (from the audit, §2)

In rough order of effort-to-value once the loop is proven:

1. **Universe-variable hygiene in hot files** — the #26018/#12737 technique
   (explicit/reordered universes can cut kernel-check time ~29% in affected
   files). Validate per-file with `!bench`.
2. **Simp-squeezing slow calls** (#19751 technique) in files the bench dashboard
   flags — mechanical, benchable, welcome.
3. **Tactic bug triage** — open correctness bugs (#741 `zify`, #8875 `linarith`)
   are high-value if anyone on the team has metaprogramming depth.

Do NOT pre-merge cherry-pick upstream WIP (e.g. #41705) into the fork, and do
not apply the above optimizations in-tree — both refuted in the audit's
adversarial review (§5).
