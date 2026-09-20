.PHONY: setup version guide check run native laws proof gpu clean

setup:
	bash scripts/bootstrap.sh

version:
	bend --version

guide:
	bend guide

# Type-check + execute the small CPU smoke example on the default JS lane.
run:
	bash scripts/run-cpu.sh

# Alias kept explicit for CI/readability.
check: run

# Compile native CPU code and use all available cores unless THREADS is supplied.
native:
	bash scripts/run-native.sh $(THREADS)

# Laws are intentionally open claims until PROOF.bend is completed.
laws:
	bend LAWS.bend

proof:
	bend PROOF.bend

gpu:
	bash scripts/run-gpu.sh

clean:
	rm -rf build
