import Base
import ./lib/sim.bend as Sim
import ./lib/pos.bend as P
import ./lib/bag.bend as B
import ./proof/spec.bend as Spec

# The optimized numeric destination counter computes the mathematical count.
law destination_counts_are_correct:
  for +ps: Sim.Batch<Sim.Proposal>
  for +dst: P.Pos
  {
    B.Bag.get(Sim.Counts.from(ps), P.Pos.key(dst))
    ==
    Spec.count_dst(ps, dst)
    : U32
  }

# A proposal never teleports.
law proposals_are_local:
  for +grid: B.Bag
  for +p: P.Pos
  for phase: Sim.Phase
  proposal = Sim.Propose.one(grid, p, phase)
  {Sim.Proposal.is_local(proposal) == True{} : Bool}

# An isolated elf stays in place.
law isolated_stays:
  for +grid: B.Bag
  for +p: P.Pos
  for phase: Sim.Phase

  {Sim.Board.has_neighbor(grid, p) == False{} : Bool} ->
  {
    Sim.Proposal.dst(Sim.Propose.one(grid, p, phase))
    ==
    p
    : P.Pos
  }

# One proposal to a destination succeeds.
law sole_proposal_moves:
  for src: P.Pos
  for dst: P.Pos
  {Sim.Resolve.one(src, dst, 1) == dst : P.Pos}

# A contested destination cancels the move.
law conflict_cancels:
  for src: P.Pos
  for dst: P.Pos
  for count: U32

  {U32.is_ge(count, 2) == True{} : Bool} ->
  {Sim.Resolve.one(src, dst, count) == src : P.Pos}

# A round preserves population.
law population_is_conserved:
  for +agents: Sim.Batch<P.Pos>
  for +phase: Sim.Phase
  {
    Sim.Batch.size(P.Pos, Sim.step(agents, phase))
    ==
    Sim.Batch.size(P.Pos, agents)
    : Nat
  }

# An entirely isolated state is a fixed point.
law isolated_state_is_stable:
  for +agents: Sim.Batch<P.Pos>
  for +phase: Sim.Phase

  {Sim.State.all_isolated(agents) == True{} : Bool} ->
  {Sim.step(agents, phase) == agents : Sim.Batch<P.Pos>}

# Direction priority cycles every four rounds.
law phase_cycles_in_four:
  for phase: Sim.Phase
  {
    Sim.Phase.next(
      Sim.Phase.next(
        Sim.Phase.next(
          Sim.Phase.next(phase)
        )
      )
    )
    ==
    phase
    : Sim.Phase
  }

# AoC worked regression example.
law aoc_small_example_after_three_rounds:
  {
    Sim.run(3n, Sim.sample(), Sim.P0{})
    ==
    Sim.sample_after_3_expected()
    : Sim.Batch<P.Pos>
  }
