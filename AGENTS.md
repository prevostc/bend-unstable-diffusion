# Working on this Bend repository

When using Bend:
- run `bend guide` to learn the current language
- treat `LAWS.bend` as human-owned specification; do not weaken laws to make a proof pass
- implement proofs in `PROOF.bend`
- run `make run` after code edits
- run `make proof` before claiming a law is proved
- preserve the central law `fast_matches_reference`
- parallelize the implementation without changing the reference semantics

Project-specific rules:
- `main.bend` contains both the simple executable reference (`step_spec`) and the optimized implementation (`step_fast`)
- prefer changing `step_fast`, never making `step_spec` more complicated just to match an optimization
- GitHub Codespaces is CPU-only; use `gpu.bend` only on a CUDA-capable remote host
