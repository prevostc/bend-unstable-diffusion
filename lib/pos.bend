import Base

type Pos is Data:
  Pos{x: U32, y: U32}


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

def Pos.key32(p: Pos) -> U32:
  match p:
    case Pos{x, y}:
      U32.or(
        U32.shln(U32.and(x, 65535), 16n),
        U32.and(y, 65535)
      )

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

