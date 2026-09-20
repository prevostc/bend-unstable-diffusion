import Base
import ./pos.bend as P
import ./bag.bend as B

# Advent of Code 2022, Day 23: Unstable Diffusion.
#
# Coordinates use U32. For exact AoC plane semantics, place the initial
# configuration far enough from 0 / 2^32-1 that no simulated round wraps.

# -----------------------------------------------------------------------------
# Domain
# -----------------------------------------------------------------------------

type Dir is Data:
  N{}
  S{}
  W{}
  E{}

type Phase is Data:
  P0{} # N S W E
  P1{} # S W E N
  P2{} # W E N S
  P3{} # E N S W

type Proposal is Data:
  Proposal{src: P.Pos, dst: P.Pos}

# A balanced tree is friendlier to Bend's fork/join parallelism than a list.
type Batch<-A: Data> is Data:
  One{value: A}
  Fork{left: Batch<A>, right: Batch<A>}

# -----------------------------------------------------------------------------
# Batch utilities
# -----------------------------------------------------------------------------

def Batch.size(-A: Data, xs: Batch<A>) -> Nat:
  match xs:
    case One{x}:
      1n
    case Fork{l, r}:
      a b = Batch.size(A, l) Batch.size(A, r)
      Nat.add(a, b)

# -----------------------------------------------------------------------------
# Occupancy / directional predicates
# -----------------------------------------------------------------------------

def Board.has(+b: B.Bag, p: P.Pos) -> Bool:
  B.Bag.has(b, P.Pos.key(p))

def Board.has_neighbor(+b: B.Bag, +p: P.Pos) -> Bool:
  Bool.or(
    Board.has(b, P.Pos.nw(p)),
    Bool.or(
      Board.has(b, P.Pos.n(p)),
      Bool.or(
        Board.has(b, P.Pos.ne(p)),
        Bool.or(
          Board.has(b, P.Pos.w(p)),
          Bool.or(
            Board.has(b, P.Pos.e(p)),
            Bool.or(
              Board.has(b, P.Pos.sw(p)),
              Bool.or(
                Board.has(b, P.Pos.s(p)),
                Board.has(b, P.Pos.se(p))
              )
            )
          )
        )
      )
    )
  )

def Board.empty3(
  +b: B.Bag,
  a: P.Pos,
  c: P.Pos,
  d: P.Pos
) -> Bool:
  Bool.not(
    Bool.or(
      Board.has(b, a),
      Bool.or(Board.has(b, c), Board.has(b, d))
    )
  )

def Dir.step(d: Dir, p: P.Pos) -> P.Pos:
  match d:
    case N{}: P.Pos.n(p)
    case S{}: P.Pos.s(p)
    case W{}: P.Pos.w(p)
    case E{}: P.Pos.e(p)

def Dir.clear(+b: B.Bag, +p: P.Pos, d: Dir) -> Bool:
  match d:
    case N{}:
      Board.empty3(b, P.Pos.nw(p), P.Pos.n(p), P.Pos.ne(p))
    case S{}:
      Board.empty3(b, P.Pos.sw(p), P.Pos.s(p), P.Pos.se(p))
    case W{}:
      Board.empty3(b, P.Pos.nw(p), P.Pos.w(p), P.Pos.sw(p))
    case E{}:
      Board.empty3(b, P.Pos.ne(p), P.Pos.e(p), P.Pos.se(p))

# -----------------------------------------------------------------------------
# Phase / proposal generation
# -----------------------------------------------------------------------------

def Phase.next(p: Phase) -> Phase:
  match p:
    case P0{}:
      P1{}
    case P1{}:
      P2{}
    case P2{}:
      P3{}
    case P3{}:
      P0{}

def Phase.dirs(p: Phase) -> List<&2, Dir>:
  match p:
    case P0{}:
      [N{}, S{}, W{}, E{}]
    case P1{}:
      [S{}, W{}, E{}, N{}]
    case P2{}:
      [W{}, E{}, N{}, S{}]
    case P3{}:
      [E{}, N{}, S{}, W{}]

def Propose.choose(
  +b: B.Bag,
  +p: P.Pos,
  dirs: List<&2, Dir>
) -> P.Pos:
  match dirs:
    case Nil{}:
      p

    case +d <> rest:
      fallback = Propose.choose(b, p, rest)

      Bool.pick(
        P.Pos,
        Dir.clear(b, p, d),
        Dir.step(d, p),
        fallback
      )

def Propose.one.go(
  +b: B.Bag,
  +p: P.Pos,
  phase: Phase,
  near: Bool
) -> Proposal:
  match near:
    case False{}:
      Proposal{p, p}
    case True{}:
      Proposal{p, Propose.choose(b, p, Phase.dirs(phase))}

def Propose.one(
  +b: B.Bag,
  +p: P.Pos,
  phase: Phase
) -> Proposal:
  Propose.one.go(
    b,
    p,
    phase,
    Board.has_neighbor(b, p)
  )

def Propose.all(
  +b: B.Bag,
  +phase: Phase,
  xs: Batch<P.Pos>
) -> Batch<Proposal>:
  match xs:
    case One{p}:
      One{Propose.one(b, p, phase)}
    case Fork{l, r}:
      a c =
        Propose.all(b, phase, l)
        Propose.all(b, phase, r)
      Fork{a, c}

def Proposal.dst(p: Proposal) -> P.Pos:
  match p:
    case Proposal{src, dst}:
      dst

def Proposal.is_local(p: Proposal) -> Bool:
  match p:
    case Proposal{+src, +dst}:
      P.Pos.cardinal_or_same(src, dst)

# -----------------------------------------------------------------------------
# Direct reference semantics (simple, intentionally O(n^2))
# -----------------------------------------------------------------------------

def Resolve.one.go(
  unique: Bool,
  src: P.Pos,
  dst: P.Pos
) -> P.Pos:
  match unique:
    case True{}:
      dst
    case False{}:
      src

def Resolve.one(
  src: P.Pos,
  dst: P.Pos,
  count: U32
) -> P.Pos:
  Resolve.one.go(
    U32.is_eq(count, 1),
    src,
    dst
  )

# -----------------------------------------------------------------------------
# Destination counts
# -----------------------------------------------------------------------------

def Counts.from(ps: Batch<Proposal>) -> B.Bag:
  match ps:
    case One{p}:
      B.Bag.add(
        B.Empty{},
        P.Pos.key(Proposal.dst(p)),
        1
      )

    case Fork{l, r}:
      a b =
        Counts.from(l)
        Counts.from(r)

      B.Bag.merge(a, b)

def Commit.one(
  +counts: B.Bag,
  p: Proposal
) -> P.Pos:
  match p:
    case Proposal{src, +dst}:
      Resolve.one(
        src,
        dst,
        B.Bag.get(counts, P.Pos.key(dst))
      )

def Commit.all(
  +counts: B.Bag,
  ps: Batch<Proposal>
) -> Batch<P.Pos>:
  match ps:
    case One{p}:
      One{Commit.one(counts, p)}

    case Fork{l, r}:
      a b =
        Commit.all(counts, l)
        Commit.all(counts, r)
      Fork{a, b}

# Build the numeric occupancy grid in parallel from the Batch.
def Board.index(agents: Batch<P.Pos>) -> B.Bag:
  match agents:
    case One{p}:
      B.Bag.add(
        B.Empty{},
        P.Pos.key(p),
        1
      )

    case Fork{l, r}:
      a b =
        Board.index(l)
        Board.index(r)

      B.Bag.merge(a, b)


# -----------------------------------------------------------------------------
# Whole round
# -----------------------------------------------------------------------------

def step(+agents: Batch<P.Pos>, +phase: Phase) -> Batch<P.Pos>:
  +board = Board.index(agents)
  +props = Propose.all(board, phase, agents)
  counts = Counts.from(props)
  Commit.all(counts, props)

def run(fuel: Nat, +agents: Batch<P.Pos>, +phase: Phase) -> Batch<P.Pos>:
  match fuel:
    case 0n:
      agents
    case 1n+p:
      run(p, step(agents, phase), Phase.next(phase))

# -----------------------------------------------------------------------------
# Predicates used by laws
# -----------------------------------------------------------------------------

def State.all_isolated.go(
  +board: B.Bag, agents: Batch<P.Pos>
) -> Bool:
  match agents:
    case One{p}:
      Bool.not(Board.has_neighbor(board, p))
    case Fork{l, r}:
      a b = State.all_isolated.go(board, l) State.all_isolated.go(board, r)
      Bool.and(a, b)

def State.all_isolated(+agents: Batch<P.Pos>) -> Bool:
  +board = Board.index(agents)
  State.all_isolated.go(board, agents)

# -----------------------------------------------------------------------------
# AoC's five-elf worked example, offset by +100 in each axis.
# -----------------------------------------------------------------------------

def sample() -> Batch<P.Pos>:
  Fork{
    Fork{One{P.Pos.make(102, 101)}, One{P.Pos.make(103, 101)}},
    Fork{
      One{P.Pos.make(102, 102)},
      Fork{One{P.Pos.make(102, 104)}, One{P.Pos.make(103, 104)}}
    }
  }

def sample_after_3_expected() -> Batch<P.Pos>:
  Fork{
    Fork{One{P.Pos.make(102, 100)}, One{P.Pos.make(104, 101)}},
    Fork{
      One{P.Pos.make(100, 102)},
      Fork{One{P.Pos.make(102, 105)}, One{P.Pos.make(104, 103)}}
    }
  }


# Build a balanced Batch from a list.

def Batch.leaves(
  xs: List<&2, P.Pos>
) -> List<&2, Batch<P.Pos>>:
  match xs:
    case Nil{}:
      Nil{}
    case p <> rest:
      One{p} <> Batch.leaves(rest)

def Batch.pair(
  xs: List<&2, Batch<P.Pos>>
) -> List<&2, Batch<P.Pos>>:
  match xs:
    case Nil{}:
      Nil{}
    case a <> rest:
      match rest:
        case Nil{}:
          [a]
        case b <> tail:
          Fork{a, b} <> Batch.pair(tail)

def Batch.collapse(
  fuel: Nat,
  xs: List<&2, Batch<P.Pos>>
) -> Maybe<&2, Batch<P.Pos>>:
  match fuel xs:
    case 0n _:
      None{}
    case 1n+p Nil{}:
      None{}
    case 1n+p a <> rest:
      match rest:
        case Nil{}:
          Some{a}
        case b <> tail:
          Batch.collapse(
            p,
            Fork{a, b} <> Batch.pair(tail)
          )

def Batch.from_list(
  +xs: List<&2, P.Pos>
) -> Maybe<&2, Batch<P.Pos>>:
  Batch.collapse(
    List.length(&2, P.Pos, xs),
    Batch.leaves(xs)
  )
