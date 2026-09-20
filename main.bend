import Base

# Advent of Code 2022, Day 23: Unstable Diffusion.
#
# This version deliberately contains two implementations of one round:
#   - step_spec: small, direct executable specification (O(n^2))
#   - step_fast: destination-count map + parallel tree traversals
#
# The main verification target is: step_fast == step_spec.
#
# Coordinates use U32. For exact AoC plane semantics, place the initial
# configuration far enough from 0 / 2^32-1 that no simulated round wraps.

# -----------------------------------------------------------------------------
# Domain
# -----------------------------------------------------------------------------

type Pos is Data:
  Pos{x: U32, y: U32}

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
  Proposal{src: Pos, dst: Pos}

# A balanced tree is friendlier to Bend's fork/join parallelism than a list.
type Batch<-A: Data> is Data:
  One{value: A}
  Fork{left: Batch<A>, right: Batch<A>}

# -----------------------------------------------------------------------------
# Positions
# -----------------------------------------------------------------------------

def Pos.eq(a: Pos, b: Pos) -> Bool:
  match a b:
    case Pos{ax, ay} Pos{bx, by}:
      Bool.and(U32.is_eq(ax, bx), U32.is_eq(ay, by))

def Pos.n(p: Pos) -> Pos:
  match p:
    case Pos{x, y}:
      Pos{x, U32.sub(y, 1)}

def Pos.s(p: Pos) -> Pos:
  match p:
    case Pos{x, y}:
      Pos{x, U32.add(y, 1)}

def Pos.w(p: Pos) -> Pos:
  match p:
    case Pos{x, y}:
      Pos{U32.sub(x, 1), y}

def Pos.e(p: Pos) -> Pos:
  match p:
    case Pos{x, y}:
      Pos{U32.add(x, 1), y}

def Pos.nw(p: Pos) -> Pos:
  match p:
    case Pos{x, y}:
      Pos{U32.sub(x, 1), U32.sub(y, 1)}

def Pos.ne(p: Pos) -> Pos:
  match p:
    case Pos{x, y}:
      Pos{U32.add(x, 1), U32.sub(y, 1)}

def Pos.sw(p: Pos) -> Pos:
  match p:
    case Pos{x, y}:
      Pos{U32.sub(x, 1), U32.add(y, 1)}

def Pos.se(p: Pos) -> Pos:
  match p:
    case Pos{x, y}:
      Pos{U32.add(x, 1), U32.add(y, 1)}

def Pos.key(p: Pos) -> String:
  match p:
    case Pos{x, y}:
      U32.show(x) ++ ":" ++ U32.show(y)

def Pos.cardinal_or_same(+src: Pos, +dst: Pos) -> Bool:
  Bool.or(
    Pos.eq(src, dst),
    Bool.or(
      Pos.eq(Pos.n(src), dst),
      Bool.or(
        Pos.eq(Pos.s(src), dst),
        Bool.or(Pos.eq(Pos.w(src), dst), Pos.eq(Pos.e(src), dst))
      )
    )
  )

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

def Batch.to_list(-A: Data, xs: Batch<A>) -> List<&2, A>:
  match xs:
    case One{x}:
      [x]
    case Fork{l, r}:
      a b = Batch.to_list(A, l) Batch.to_list(A, r)
      List.append(&2, A, a, b)

# -----------------------------------------------------------------------------
# Occupancy / directional predicates
# -----------------------------------------------------------------------------

def Board.occupied(+xs: List<&2, Pos>, +q: Pos) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case +h <> t:
      Board.occupied.go(t, q, Pos.eq(h, q))

def Board.occupied.go(+tail: List<&2, Pos>, +q: Pos, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      Board.occupied(tail, q)

def Board.has_neighbor(+b: List<&2, Pos>, +p: Pos) -> Bool:
  Bool.or(
    Board.occupied(b, Pos.nw(p)),
    Bool.or(
      Board.occupied(b, Pos.n(p)),
      Bool.or(
        Board.occupied(b, Pos.ne(p)),
        Bool.or(
          Board.occupied(b, Pos.w(p)),
          Bool.or(
            Board.occupied(b, Pos.e(p)),
            Bool.or(
              Board.occupied(b, Pos.sw(p)),
              Bool.or(Board.occupied(b, Pos.s(p)), Board.occupied(b, Pos.se(p)))
            )
          )
        )
      )
    )
  )

def Dir.step(d: Dir, p: Pos) -> Pos:
  match d:
    case N{}:
      Pos.n(p)
    case S{}:
      Pos.s(p)
    case W{}:
      Pos.w(p)
    case E{}:
      Pos.e(p)

def Dir.clear(+b: List<&2, Pos>, +p: Pos, d: Dir) -> Bool:
  match d:
    case N{}:
      Bool.not(Bool.or(
        Board.occupied(b, Pos.nw(p)),
        Bool.or(Board.occupied(b, Pos.n(p)), Board.occupied(b, Pos.ne(p)))
      ))
    case S{}:
      Bool.not(Bool.or(
        Board.occupied(b, Pos.sw(p)),
        Bool.or(Board.occupied(b, Pos.s(p)), Board.occupied(b, Pos.se(p)))
      ))
    case W{}:
      Bool.not(Bool.or(
        Board.occupied(b, Pos.nw(p)),
        Bool.or(Board.occupied(b, Pos.w(p)), Board.occupied(b, Pos.sw(p)))
      ))
    case E{}:
      Bool.not(Bool.or(
        Board.occupied(b, Pos.ne(p)),
        Bool.or(Board.occupied(b, Pos.e(p)), Board.occupied(b, Pos.se(p)))
      ))

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

def Propose.choose(+b: List<&2, Pos>, +p: Pos, dirs: List<&2, Dir>) -> Pos:
  match dirs:
    case Nil{}:
      p
    case +d <> rest:
      Propose.choose.go(b, p, rest, d, Dir.clear(b, p, d))

def Propose.choose.go(
  +b: List<&2, Pos>, +p: Pos, rest: List<&2, Dir>, d: Dir, clear: Bool
) -> Pos:
  match clear:
    case True{}:
      Dir.step(d, p)
    case False{}:
      Propose.choose(b, p, rest)

def Propose.after_neighbor(
  +b: List<&2, Pos>, +p: Pos, phase: Phase, near: Bool
) -> Proposal:
  match near:
    case False{}:
      Proposal{p, p}
    case True{}:
      Proposal{p, Propose.choose(b, p, Phase.dirs(phase))}

def Propose.one(+b: List<&2, Pos>, +p: Pos, phase: Phase) -> Proposal:
  Propose.after_neighbor(b, p, phase, Board.has_neighbor(b, p))

def Propose.all(
  +b: List<&2, Pos>, +phase: Phase, xs: Batch<Pos>
) -> Batch<Proposal>:
  match xs:
    case One{p}:
      One{Propose.one(b, p, phase)}
    case Fork{l, r}:
      a c = Propose.all(b, phase, l) Propose.all(b, phase, r)
      Fork{a, c}

def Proposal.src(p: Proposal) -> Pos:
  match p:
    case Proposal{src, dst}:
      src

def Proposal.dst(p: Proposal) -> Pos:
  match p:
    case Proposal{src, dst}:
      dst

def Proposal.is_local(p: Proposal) -> Bool:
  match p:
    case Proposal{+src, +dst}:
      Pos.cardinal_or_same(src, dst)

# -----------------------------------------------------------------------------
# Direct reference semantics (simple, intentionally O(n^2))
# -----------------------------------------------------------------------------

def Proposal.count_dst(+all: Batch<Proposal>, +dst: Pos) -> U32:
  match all:
    case One{p}:
      Bool.to_u32(Pos.eq(Proposal.dst(p), dst))
    case Fork{l, r}:
      a b = Proposal.count_dst(l, dst) Proposal.count_dst(r, dst)
      U32.add(a, b)

def Resolve.one(src: Pos, dst: Pos, count: U32) -> Pos:
  Resolve.one.go(src, dst, U32.is_eq(count, 1))

def Resolve.one.go(src: Pos, dst: Pos, unique: Bool) -> Pos:
  match unique:
    case True{}:
      dst
    case False{}:
      src

def Commit.ref.one(+all: Batch<Proposal>, p: Proposal) -> Pos:
  match p:
    case Proposal{src, +dst}:
      Resolve.one(src, dst, Proposal.count_dst(all, dst))

def Commit.ref.all(+all: Batch<Proposal>, ps: Batch<Proposal>) -> Batch<Pos>:
  match ps:
    case One{p}:
      One{Commit.ref.one(all, p)}
    case Fork{l, r}:
      a b = Commit.ref.all(all, l) Commit.ref.all(all, r)
      Fork{a, b}

# -----------------------------------------------------------------------------
# Faster conflict counting
# -----------------------------------------------------------------------------

# Base.Map is String-keyed today, so Pos.key is used here. For the eventual
# benchmark, replace this with a U32-keyed radix trie / dense spatial table;
# the law step_fast == step_spec should remain unchanged.

def Counts.singleton(p: Pos) -> Map<&2, U32>:
  Map.set(&2, U32, MTip{}, Pos.key(p), 1)

def Counts.add(m: Map<&2, U32>, +key: String, add: U32) -> Map<&2, U32>:
  (m2, old) = Map.get(U32, 0, m, key)
  Map.set(&2, U32, m2, key, U32.add(old, add))

# Structural recursion is on the first map argument.
def Counts.merge(b: Map<&2, U32>, a: Map<&2, U32>) -> Map<&2, U32>:
  match b:
    case MTip{}:
      a
    case MLeaf{k, v}:
      Counts.add(a, k, v)
    case MNode{pos, lo, hi}:
      a2 = Counts.merge(lo, a)
      Counts.merge(hi, a2)

def Counts.from(ps: Batch<Proposal>) -> Map<&2, U32>:
  match ps:
    case One{p}:
      Counts.singleton(Proposal.dst(p))
    case Fork{l, r}:
      a b = Counts.from(l) Counts.from(r)
      Counts.merge(b, a)

def Counts.at(m: Map<&2, U32>, p: Pos) -> U32:
  (m2, n) = Map.get(U32, 0, m, Pos.key(p))
  n

def Commit.fast.one(+counts: Map<&2, U32>, p: Proposal) -> Pos:
  match p:
    case Proposal{src, +dst}:
      Resolve.one(src, dst, Counts.at(counts, dst))

def Commit.fast.all(
  +counts: Map<&2, U32>, ps: Batch<Proposal>
) -> Batch<Pos>:
  match ps:
    case One{p}:
      One{Commit.fast.one(counts, p)}
    case Fork{l, r}:
      a b = Commit.fast.all(counts, l) Commit.fast.all(counts, r)
      Fork{a, b}

# -----------------------------------------------------------------------------
# Whole round: spec vs optimized implementation
# -----------------------------------------------------------------------------

def step_spec(+agents: Batch<Pos>, +phase: Phase) -> Batch<Pos>:
  +board = Batch.to_list(Pos, agents)
  +props = Propose.all(board, phase, agents)
  Commit.ref.all(props, props)

def step_fast(+agents: Batch<Pos>, +phase: Phase) -> Batch<Pos>:
  +board = Batch.to_list(Pos, agents)
  +props = Propose.all(board, phase, agents)
  counts = Counts.from(props)
  Commit.fast.all(counts, props)

def run(fuel: Nat, +agents: Batch<Pos>, phase: Phase) -> Batch<Pos>:
  match fuel:
    case 0n:
      agents
    case 1n+p:
      run(p, step_fast(agents, phase), Phase.next(phase))

# -----------------------------------------------------------------------------
# Predicates used by laws
# -----------------------------------------------------------------------------

def Board.unique(xs: List<&2, Pos>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      +tail = t
      Board.unique.go(tail, Board.occupied(tail, h))

def Board.unique.go(tail: List<&2, Pos>, duplicate: Bool) -> Bool:
  match duplicate:
    case True{}:
      False{}
    case False{}:
      Board.unique(tail)

def State.unique(agents: Batch<Pos>) -> Bool:
  Board.unique(Batch.to_list(Pos, agents))

def State.all_isolated.go(
  +board: List<&2, Pos>, agents: Batch<Pos>
) -> Bool:
  match agents:
    case One{p}:
      Bool.not(Board.has_neighbor(board, p))
    case Fork{l, r}:
      a b = State.all_isolated.go(board, l) State.all_isolated.go(board, r)
      Bool.and(a, b)

def State.all_isolated(+agents: Batch<Pos>) -> Bool:
  +board = Batch.to_list(Pos, agents)
  State.all_isolated.go(board, agents)

# -----------------------------------------------------------------------------
# AoC's five-elf worked example, offset by +100 in each axis.
# -----------------------------------------------------------------------------

def sample() -> Batch<Pos>:
  Fork{
    Fork{One{Pos{102, 101}}, One{Pos{103, 101}}},
    Fork{
      One{Pos{102, 102}},
      Fork{One{Pos{102, 104}}, One{Pos{103, 104}}}
    }
  }

def sample_after_3_expected() -> Batch<Pos>:
  Fork{
    Fork{One{Pos{102, 100}}, One{Pos{104, 101}}},
    Fork{
      One{Pos{100, 102}},
      Fork{One{Pos{102, 105}}, One{Pos{104, 103}}}
    }
  }

# Tiny executable smoke test for Codespaces / CPU. The GPU entrypoint lives in
# gpu.bend; the interesting benchmark should generate a much larger balanced Batch.
def main() -> IO(Unit):
  result = run(3n, sample(), P0{})
  IO.print("elves after 3 rounds: " ++ Nat.show(Batch.size(Pos, result)))
