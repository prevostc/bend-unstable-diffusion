# Human-owned specification for Unstable Diffusion.

import Base
import ./main.bend as Sim

# 1. CORE LAW
# The optimized destination-count implementation must be exactly the same
# transition function as the deliberately simple executable specification.
law fast_matches_reference:
  for +agents: Sim.Batch<Sim.Pos>
  for +phase: Sim.Phase
  {Sim.step_fast(agents, phase) == Sim.step_spec(agents, phase) : Sim.Batch<Sim.Pos>}

# 2. A proposal is never a teleport: it stays put or moves one cardinal cell.
law proposals_are_local:
  for +board: List<&2, Sim.Pos>
  for +p: Sim.Pos
  for phase: Sim.Phase
  proposal = Sim.Propose.one(board, p, phase)
  {Sim.Proposal.is_local(proposal) == True{} : Bool}

# 3. An isolated elf does not propose movement.
law isolated_stays:
  for +board: List<&2, Sim.Pos>
  for +p: Sim.Pos
  for phase: Sim.Phase
  {Sim.Board.has_neighbor(board, p) == False{} : Bool} ->
  {Sim.Proposal.dst(Sim.Propose.one(board, p, phase)) == p : Sim.Pos}

# 4. Exactly one proposal to a destination succeeds.
law sole_proposal_moves:
  for src: Sim.Pos
  for dst: Sim.Pos
  {Sim.Resolve.one(src, dst, 1) == dst : Sim.Pos}

# 5. A contested destination cancels movement.
law conflict_cancels:
  for src: Sim.Pos
  for dst: Sim.Pos
  for count: U32
  {U32.is_ge(count, 2) == True{} : Bool} ->
  {Sim.Resolve.one(src, dst, count) == src : Sim.Pos}

# 6. A round neither creates nor destroys elves.
law population_is_conserved:
  for +agents: Sim.Batch<Sim.Pos>
  for +phase: Sim.Phase
  {Sim.Batch.size(Sim.Pos, Sim.step_fast(agents, phase)) == Sim.Batch.size(Sim.Pos, agents) : Nat}

# 7. Starting with one elf per tile, a round still has one elf per tile.
# This is the key application-level safety invariant of the simultaneous commit.
law unique_positions_are_preserved:
  for +agents: Sim.Batch<Sim.Pos>
  for +phase: Sim.Phase
  {Sim.State.unique(agents) == True{} : Bool} ->
  {Sim.State.unique(Sim.step_fast(agents, phase)) == True{} : Bool}

# 8. If every elf is isolated, the state is already a fixed point.
law isolated_state_is_stable:
  for +agents: Sim.Batch<Sim.Pos>
  for +phase: Sim.Phase
  {Sim.State.all_isolated(agents) == True{} : Bool} ->
  {Sim.step_fast(agents, phase) == agents : Sim.Batch<Sim.Pos>}

# 9. Direction priority cycles every four rounds.
law phase_cycles_in_four:
  for phase: Sim.Phase
  {Sim.Phase.next(Sim.Phase.next(Sim.Phase.next(Sim.Phase.next(phase)))) == phase : Sim.Phase}

# 10. Regression against the worked example in the AoC statement.
law aoc_small_example_after_three_rounds:
  {Sim.run(3n, Sim.sample(), Sim.P0{}) == Sim.sample_after_3_expected() : Sim.Batch<Sim.Pos>}
