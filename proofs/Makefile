.PHONY: build audit roadmap clean

LIB := CausalLoopDiagramsProofs

# Build the default target; must be sorry-free and warning-free.
build:
	lake build --wfail

# Print the axioms every headline theorem uses. None are expected: the proofs are case
# splits and list inductions.
audit:
	lake env lean Audit.lean

# The remaining-work module. It contains documentation and no declarations, so this only
# checks that the file still elaborates.
roadmap:
	lake build $(LIB).Roadmap

clean:
	lake clean
