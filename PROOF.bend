import Base
import ./LAWS.bend as Laws
import ./sim.bend as Sim

def Laws.destination_counts_are_correct(ps, dst):
  ?TODO

def Laws.proposals_are_local(grid, p, phase):
  ?TODO

def Laws.isolated_stays(grid, p, phase, isolated):
  ?TODO

def Laws.sole_proposal_moves(src, dst):
  {==}

def Laws.conflict_cancels(src, dst, count, contested):
  ?TODO

def Laws.population_is_conserved(agents, phase):
  ?TODO

def Laws.isolated_state_is_stable(agents, phase, isolated):
  ?TODO

def Laws.phase_cycles_in_four(phase):
  match phase:
    case Sim.P0{}:
      {==}
    case Sim.P1{}:
      {==}
    case Sim.P2{}:
      {==}
    case Sim.P3{}:
      {==}

def Laws.aoc_small_example_after_three_rounds():
  ?TODO
