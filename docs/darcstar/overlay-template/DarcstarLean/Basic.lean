/-
Copyright (c) 2026 DarcStar Technologies. All rights reserved.
Released under Apache 2.0 license.
-/
import Mathlib.Data.Nat.Prime.Infinite
import Mathlib.Tactic.NormNum.Prime

/-!
# DarcStar Lean extensions — sample module

This module exists to prove the overlay-package model works: org-authored code
building on top of a pinned, cache-served mathlib. Replace its contents with real
org lemmas/tactics; keep one import line per new module in `DarcstarLean.lean`.

Everything imported from `Mathlib.*` arrives as a prebuilt `.olean` via
`lake exe cache get` — only the code in this package compiles locally.
-/

namespace DarcStar

/-- Sample fact discharged by mathlib's `norm_num` prime extension. -/
theorem prime_101 : Nat.Prime 101 := by norm_num

/-- Sample lemma built on mathlib API (Euclid's theorem). -/
theorem exists_prime_gt (n : ℕ) : ∃ p, n < p ∧ p.Prime := by
  obtain ⟨p, hle, hp⟩ := Nat.exists_infinite_primes (n + 1)
  exact ⟨p, hle, hp⟩

end DarcStar
