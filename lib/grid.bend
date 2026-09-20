import Base
import ./pos.bend as P
import ./u32bag.bend as T

def Grid.empty() -> T.Trie:
  T.Tip{}

def Grid.add(
  grid: T.Trie,
  p: P.Pos,
  amount: U32
) -> T.Trie:
  T.Trie.add(grid, P.Pos.key32(p), amount)

def Grid.get(
  +grid: T.Trie,
  p: P.Pos
) -> U32:
  T.Trie.get(grid, P.Pos.key32(p))

def Grid.has(
  +grid: T.Trie,
  p: P.Pos
) -> Bool:
  U32.is_ne(Grid.get(grid, p), 0)

def Grid.merge(
  a: T.Trie,
  b: T.Trie
) -> T.Trie:
  T.Trie.merge(a, b)

def Grid.has_neighbor8(
  +grid: T.Trie,
  +p: P.Pos
) -> Bool:
  Bool.or(
    Grid.has(grid, P.Pos.nw(p)),
    Bool.or(
      Grid.has(grid, P.Pos.n(p)),
      Bool.or(
        Grid.has(grid, P.Pos.ne(p)),
        Bool.or(
          Grid.has(grid, P.Pos.w(p)),
          Bool.or(
            Grid.has(grid, P.Pos.e(p)),
            Bool.or(
              Grid.has(grid, P.Pos.sw(p)),
              Bool.or(
                Grid.has(grid, P.Pos.s(p)),
                Grid.has(grid, P.Pos.se(p))
              )
            )
          )
        )
      )
    )
  )
