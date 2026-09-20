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
    case h <> t:
      Bool.or(Pos.eq(h, q), Board.occupied(t, q))


# -----------------------------------------------------------------------------
# Fast occupancy index
# -----------------------------------------------------------------------------

def Board.index_merge(
  b: Map<&2, U32>,
  a: Map<&2, U32>
) -> Map<&2, U32>:
  match b:
    case MTip{}:
      a
    case MLeaf{k, v}:
      Map.set(&2, U32, a, k, 1)
    case MNode{pos, lo, hi}:
      a2 = Board.index_merge(lo, a)
      Board.index_merge(hi, a2)

def Board.index(xs: Batch<Pos>) -> Map<&2, U32>:
  match xs:
    case One{p}:
      Map.set(&2, U32, MTip{}, Pos.key(p), 1)
    case Fork{l, r}:
      a b = Board.index(l) Board.index(r)
      Board.index_merge(b, a)

def Board.occupied_fast_got(
  got: Map<&2, U32> & U32
) -> Bool:
  (_m, n) = got
  U32.is_ne(n, 0)

def Board.occupied_fast(
  m: Map<&2, U32>,
  p: Pos
) -> Bool:
  Board.occupied_fast_got(
    Map.get(U32, 0, m, Pos.key(p))
  )

def Board.has_neighbor_fast(
  +b: Map<&2, U32>,
  +p: Pos
) -> Bool:
  Bool.or(
    Board.occupied_fast(b, Pos.nw(p)),
    Bool.or(
      Board.occupied_fast(b, Pos.n(p)),
      Bool.or(
        Board.occupied_fast(b, Pos.ne(p)),
        Bool.or(
          Board.occupied_fast(b, Pos.w(p)),
          Bool.or(
            Board.occupied_fast(b, Pos.e(p)),
            Bool.or(
              Board.occupied_fast(b, Pos.sw(p)),
              Bool.or(
                Board.occupied_fast(b, Pos.s(p)),
                Board.occupied_fast(b, Pos.se(p))
              )
            )
          )
        )
      )
    )
  )

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


def Dir.clear_fast(
  +b: Map<&2, U32>,
  +p: Pos,
  d: Dir
) -> Bool:
  match d:
    case N{}:
      Bool.not(
        Bool.or(
          Board.occupied_fast(b, Pos.nw(p)),
          Bool.or(
            Board.occupied_fast(b, Pos.n(p)),
            Board.occupied_fast(b, Pos.ne(p))
          )
        )
      )
    case S{}:
      Bool.not(
        Bool.or(
          Board.occupied_fast(b, Pos.sw(p)),
          Bool.or(
            Board.occupied_fast(b, Pos.s(p)),
            Board.occupied_fast(b, Pos.se(p))
          )
        )
      )
    case W{}:
      Bool.not(
        Bool.or(
          Board.occupied_fast(b, Pos.nw(p)),
          Bool.or(
            Board.occupied_fast(b, Pos.w(p)),
            Board.occupied_fast(b, Pos.sw(p))
          )
        )
      )
    case E{}:
      Bool.not(
        Bool.or(
          Board.occupied_fast(b, Pos.ne(p)),
          Bool.or(
            Board.occupied_fast(b, Pos.e(p)),
            Board.occupied_fast(b, Pos.se(p))
          )
        )
      )

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

def Propose.pick(clear: Bool, yes: Pos, no: Pos) -> Pos:
  match clear:
    case True{}:
      yes
    case False{}:
      no

def Propose.choose(+b: List<&2, Pos>, +p: Pos, dirs: List<&2, Dir>) -> Pos:
  match dirs:
    case Nil{}:
      p
    case +d <> rest:
      fallback = Propose.choose(b, p, rest)
      Propose.pick(
        Dir.clear(b, p, d),
        Dir.step(d, p),
        fallback
      )

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


def Propose.choose_fast(
  +b: Map<&2, U32>,
  +p: Pos,
  dirs: List<&2, Dir>
) -> Pos:
  match dirs:
    case Nil{}:
      p
    case +d <> rest:
      fallback = Propose.choose_fast(b, p, rest)
      Propose.pick(
        Dir.clear_fast(b, p, d),
        Dir.step(d, p),
        fallback
      )

def Propose.after_neighbor_fast(
  +b: Map<&2, U32>,
  +p: Pos,
  phase: Phase,
  near: Bool
) -> Proposal:
  match near:
    case False{}:
      Proposal{p, p}
    case True{}:
      Proposal{
        p,
        Propose.choose_fast(b, p, Phase.dirs(phase))
      }

def Propose.one_fast(
  +b: Map<&2, U32>,
  +p: Pos,
  phase: Phase
) -> Proposal:
  Propose.after_neighbor_fast(
    b,
    p,
    phase,
    Board.has_neighbor_fast(b, p)
  )

def Propose.all_fast(
  +b: Map<&2, U32>,
  +phase: Phase,
  xs: Batch<Pos>
) -> Batch<Proposal>:
  match xs:
    case One{p}:
      One{Propose.one_fast(b, p, phase)}
    case Fork{l, r}:
      a c =
        Propose.all_fast(b, phase, l)
        Propose.all_fast(b, phase, r)
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

def Resolve.one.go(unique: Bool, src: Pos, dst: Pos) -> Pos:
  match unique:
    case True{}:
      dst
    case False{}:
      src

def Resolve.one(src: Pos, dst: Pos, count: U32) -> Pos:
  Resolve.one.go(U32.is_eq(count, 1), src, dst)

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

def Counts.add_got(
  got: Map<&2, U32> & U32,
  +key: String,
  add: U32
) -> Map<&2, U32>:
  (m2, old) = got
  Map.set(&2, U32, m2, key, U32.add(old, add))

def Counts.add(m: Map<&2, U32>, +key: String, add: U32) -> Map<&2, U32>:
  Counts.add_got(Map.get(U32, 0, m, key), key, add)

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

def Counts.at_got(got: Map<&2, U32> & U32) -> U32:
  (_m, n) = got
  n

def Counts.at(m: Map<&2, U32>, p: Pos) -> U32:
  Counts.at_got(Map.get(U32, 0, m, Pos.key(p)))

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
  +board = Board.index(agents)
  +props = Propose.all_fast(board, phase, agents)
  counts = Counts.from(props)
  Commit.fast.all(counts, props)

def run(fuel: Nat, +agents: Batch<Pos>, +phase: Phase) -> Batch<Pos>:
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
    case h <> +t:
      Bool.and(
        Bool.not(Board.occupied(t, h)),
        Board.unique(t)
      )

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


# -----------------------------------------------------------------------------
# AoC input parsing / CLI
# -----------------------------------------------------------------------------

# Turn a '#' cell into an elf position; '.' contributes nothing.
def Input.cell(
  hit: Bool,
  p: Pos,
  rest: List<&2, Pos>
) -> List<&2, Pos>:
  match hit:
    case False{}:
      rest
    case True{}:
      p <> rest

def Input.row(
  chars: List<&2, Char>,
  +x: U32,
  +y: U32
) -> List<&2, Pos>:
  match chars:
    case Nil{}:
      Nil{}
    case c <> rest:
      tail = Input.row(rest, U32.add(x, 1), y)
      Input.cell(
        Char.is_eq(c, '#'),
        Pos{U32.add(x, 10000), U32.add(y, 10000)},
        tail
      )

def Input.rows(
  lines: List<&2, String>,
  +y: U32
) -> List<&2, Pos>:
  match lines:
    case Nil{}:
      Nil{}
    case row <> rest:
      here = Input.row(String.to_list(row), 0, y)
      below = Input.rows(rest, U32.add(y, 1))
      List.append(&2, Pos, here, below)

# Convert the parsed list into the Batch representation expected by the
# parallel simulation.
def Batch.leaves(
  xs: List<&2, Pos>
) -> List<&2, Batch<Pos>>:
  match xs:
    case Nil{}:
      Nil{}
    case p <> rest:
      One{p} <> Batch.leaves(rest)

# Pair adjacent trees in one pass:
# [a,b,c,d,e] -> [Fork(a,b), Fork(c,d), e]
def Batch.pair(
  xs: List<&2, Batch<Pos>>
) -> List<&2, Batch<Pos>>:
  match xs:
    case Nil{}:
      Nil{}
    case a <> rest:
      match rest:
        case Nil{}:
          [a]
        case b <> tail:
          Fork{a, b} <> Batch.pair(tail)

# Repeated pairing reduces the list to one balanced tree.
# fuel makes termination structurally obvious to Bend.
def Batch.collapse(
  fuel: Nat,
  xs: List<&2, Batch<Pos>>
) -> Maybe<&2, Batch<Pos>>:
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
  +xs: List<&2, Pos>
) -> Maybe<&2, Batch<Pos>>:
  Batch.collapse(
    List.length(&2, Pos, xs),
    Batch.leaves(xs)
  )

# File.read returns the File handle back together with the Result.
def Input.read_ok(file: File, text: String) -> IO(String):
  do IO<String>:
    u : Unit <- File.close(file)
    return text

def Input.read_fail(file: File, err: U32 & String) -> IO(String):
  (code, message) = err
  do IO<String>:
    u : Unit <- File.close(file)
    IO.die(String, code, message)

def Input.read_result(
  pair: File & Result<&1, &1, U32 & String, String>
) -> IO(String):
  (file, result) = pair
  match result:
    case Done{text}:
      Input.read_ok(file, text)
    case Fail{error}:
      Input.read_fail(file, error)

def Input.read(path: String) -> IO(String):
  do IO<String>:
    file : File <- IO.try(File, File.open(path, "r"))
    pair : File & Result<&1, &1, U32 & String, String> <-
      File.read(file, 1048576)
    text : String <- Input.read_result(pair)
    return text

def Input.run(parsed: Maybe<&2, Batch<Pos>>) -> IO(Unit):
  match parsed:
    case None{}:
      IO.die(Unit, 1, "input contains no elves")
    case Some{agents}:
      +result = run(10n, agents, P0{})
      IO.print(
        "elves after 10 rounds: "
        ++ Nat.show(Batch.size(Pos, result))
      )

def Input.main_args(args: List<String>) -> IO(Unit):
  match args:
    case Nil{}:
      IO.die(Unit, 1, "usage: bend main.bend input.txt")
    case path <> rest:
      do IO<Unit>:
        text : String <- Input.read(path)
        Input.run(
          Batch.from_list(
            Input.rows(String.lines(text), 0)
          )
        )

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    Input.main_args(args)
