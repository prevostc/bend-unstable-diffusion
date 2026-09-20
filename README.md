# Verified Unstable Diffusion in Bend

A Bend 2 prototype of **Advent of Code 2022, Day 23 — Unstable Diffusion**.

The project deliberately keeps two transition functions:

- `step_spec`: small, direct, intentionally slow executable semantics.
- `step_fast`: a more parallel implementation using proposal generation, destination counting, and parallel commit.

The central formal goal is:

```bend
law fast_matches_reference:
  for +agents: Sim.Batch<Sim.Pos>
  for +phase: Sim.Phase
  {Sim.step_fast(agents, phase) == Sim.step_spec(agents, phase) : Sim.Batch<Sim.Pos>}
```

## Run entirely in GitHub Codespaces

You do **not** need Bend installed locally.

1. Push this repository to GitHub.
2. On the repository page choose **Code → Codespaces → Create codespace on main**.
3. Wait for the container to finish its `postCreateCommand`. It installs Bend with the current official installer.
4. In the Codespaces terminal run:

```bash
make run
```

Useful commands:

```bash
make version   # installed Bend version
make guide     # current Bend language guide
make run       # check + run the small smoke example (JS lane)
make native    # compile a native CPU binary and run it on available cores
make laws      # check the human-owned law file (laws are open until proved)
make proof     # proof gate; expected to fail while PROOF.bend still has TODOs
make gpu       # CUDA path; not available in GitHub Codespaces
```

## Why two entrypoints?

`main.bend` is Codespaces-friendly and calls `run` normally. Its divide-and-conquer calls are still parallel when compiled natively.

`gpu.bend` calls `Sim.run!`, which asks Bend to prepare the GPU path. Compile/run that file only on a Linux host with CUDA 12 and an NVIDIA GPU.

GitHub Codespaces currently gives you remote CPU machines, not an NVIDIA GPU, so it is excellent for editing, checking, proving, and CPU runs but not for the final CUDA benchmark.

## Repository layout

```text
.
├── main.bend                 # implementation + executable reference semantics
├── gpu.bend                  # CUDA entrypoint
├── LAWS.bend                 # human-owned correctness laws
├── PROOF.bend                # proof skeleton; TODOs intentionally remain
├── AGENTS.md                 # instructions for coding agents
├── Makefile
├── scripts/
│   ├── bootstrap.sh          # installs Bend in remote environments
│   ├── run-cpu.sh
│   ├── run-native.sh
│   └── run-gpu.sh
├── .devcontainer/
│   ├── devcontainer.json     # GitHub Codespaces config
│   └── Dockerfile
└── .github/workflows/
    └── environment.yml       # manually-triggered remote smoke test
```

## Current status

This is deliberately an **experimental Bend 2 draft**. Bend itself is young and changes quickly. The repository therefore installs the current official Bend release in Codespaces rather than assuming a local compiler.

The first useful remote session is:

```bash
make version
make run
```

If `make run` reports syntax/type errors due to a Bend update, use `bend guide` and `bend base <name>` inside the Codespace to update the draft. Once the program checks, the next milestone is replacing the TODOs in `PROOF.bend`, with `fast_matches_reference` as the main theorem.

## GPU later

On a CUDA 12 remote host:

```bash
bash scripts/bootstrap.sh
make gpu
```

For a real performance demo, the tiny five-agent AoC sample should be replaced by a generated balanced `Batch` containing a much larger configuration; the laws should remain unchanged.
