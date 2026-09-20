import Base
import ../main.bend as Sim
import ../lib/pos.bend as P

def count_dst(
  +all: Sim.Batch<Sim.Proposal>,
  +dst: P.Pos
) -> U32:
  match all:
    case Sim.One{p}:
      Bool.to_u32(
        P.Pos.eq(
          Sim.Proposal.dst(p),
          dst
        )
      )

    case Sim.Fork{l, r}:
      a b =
        count_dst(l, dst)
        count_dst(r, dst)

      U32.add(a, b)
