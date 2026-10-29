.PHONY: build core theory audit audit-theory mathlib-free roadmap clean

LIB := CausalLoopDiagramsProofs

# Every module of the Mathlib-free core. `Theory/` is deliberately absent: ADR 0028 confines
# the Mathlib dependency to that one library, and `make mathlib-free` checks the confinement.
CORE := $(LIB).lean Audit.lean $(filter-out $(LIB)/Theory.lean,$(wildcard $(LIB)/*.lean))

# Both libraries. Each must be sorry-free and warning-free.
build: core theory

# The default target: the polarity rig, Mathlib-free. A clean build takes seconds.
core:
	lake build --wfail

# The composition theorem, against Mathlib (ADR 0028). The first build after a cold start
# spends minutes reading ~5 GB of Mathlib oleans; that is I/O, not elaboration, and a second
# build of the same files takes seconds.
theory:
	lake build --wfail Theory

# Print the axioms every headline theorem of the core uses. Beyond `propext` in the list
# inductions, none are expected: the rig and order proofs are finite case splits.
audit:
	lake env lean Audit.lean

# The same for the composition theorem, which inherits Mathlib's three standard axioms --
# the price of the real numbers, and the reason the two audits are separate files.
audit-theory:
	lake env lean AuditTheory.lean

# ADR 0028's separation: nothing the default target builds may reach Mathlib, either
# directly or through `Theory`.
mathlib-free:
	@if grep -lE '^import (Mathlib|$(LIB)\.Theory)' $(CORE); then \
	  echo "ERROR: a core module reaches Mathlib; ADR 0028 confines it to Theory/"; exit 1; \
	else echo "OK: the default target reaches no Mathlib (ADR 0028)"; fi

# The remaining-work module. It contains documentation and no declarations, so this only
# checks that the file still elaborates.
roadmap:
	lake build $(LIB).Roadmap

clean:
	lake clean
