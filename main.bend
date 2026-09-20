import Base
import ./lib/pos.bend as P
import ./lib/bag.bend as B

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


# -----------------------------------------------------------------------------
# AoC input parsing / CLI
# -----------------------------------------------------------------------------

# Turn a '#' cell into an elf position; '.' contributes nothing.
def Input.cell(
  hit: Bool,
  p: P.Pos,
  rest: List<&2, P.Pos>
) -> List<&2, P.Pos>:
  match hit:
    case False{}:
      rest
    case True{}:
      p <> rest

def Input.row(
  chars: List<&2, Char>,
  +x: U32,
  +y: U32
) -> List<&2, P.Pos>:
  match chars:
    case Nil{}:
      Nil{}
    case c <> rest:
      tail = Input.row(rest, U32.add(x, 1), y)
      Input.cell(
        Char.is_eq(c, '#'),
        P.Pos.make(
          U32.add(x, 10000),
          U32.add(y, 10000)
        ),
        tail
      )

def Input.rows(
  lines: List<&2, String>,
  +y: U32
) -> List<&2, P.Pos>:
  match lines:
    case Nil{}:
      Nil{}
    case row <> rest:
      here = Input.row(String.to_list(row), 0, y)
      below = Input.rows(rest, U32.add(y, 1))
      List.append(&2, P.Pos, here, below)

# Convert the parsed list into the Batch representation expected by the
# parallel simulation.
def Batch.leaves(
  xs: List<&2, P.Pos>
) -> List<&2, Batch<P.Pos>>:
  match xs:
    case Nil{}:
      Nil{}
    case p <> rest:
      One{p} <> Batch.leaves(rest)

# Pair adjacent trees in one pass:
# [a,b,c,d,e] -> [Fork(a,b), Fork(c,d), e]
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

# Repeated pairing reduces the list to one balanced tree.
# fuel makes termination structurally obvious to Bend.
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

def Input.run(parsed: Maybe<&2, Batch<P.Pos>>) -> IO(Unit):
  match parsed:
    case None{}:
      IO.die(Unit, 1, "input contains no elves")
    case Some{agents}:
      +result = run(10n, agents, P0{})
      IO.print(
        "elves after 10 rounds: "
        ++ Nat.show(Batch.size(P.Pos, result))
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
