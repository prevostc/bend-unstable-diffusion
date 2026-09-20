import Base
import ./pos.bend as P

def Parse.cell(
  hit: Bool,
  p: P.Pos,
  rest: List<&2, P.Pos>
) -> List<&2, P.Pos>:
  match hit:
    case False{}:
      rest
    case True{}:
      p <> rest

def Parse.row(
  chars: List<&2, Char>,
  +x: U32,
  +y: U32
) -> List<&2, P.Pos>:
  match chars:
    case Nil{}:
      Nil{}

    case c <> rest:
      tail = Parse.row(rest, U32.add(x, 1), y)

      Parse.cell(
        Char.is_eq(c, '#'),
        P.Pos.make(
          U32.add(x, 10000),
          U32.add(y, 10000)
        ),
        tail
      )

def Parse.rows(
  lines: List<&2, String>,
  +y: U32
) -> List<&2, P.Pos>:
  match lines:
    case Nil{}:
      Nil{}

    case row <> rest:
      here = Parse.row(String.to_list(row), 0, y)
      below = Parse.rows(rest, U32.add(y, 1))

      List.append(&2, P.Pos, here, below)

def Parse.positions(text: String) -> List<&2, P.Pos>:
  Parse.rows(String.lines(text), 0)
