import Base

# x occupies the high 16 bits, y the low 16 bits.
type Pos is Data:
  Pos{key: U32}

def Pos.make(x: U32, y: U32) -> Pos:
  Pos{U32.or(U32.shln(x, 16n), y)}

def Pos.key(p: Pos) -> U32:
  match p:
    case Pos{k}:
      k

def Pos.eq(a: Pos, b: Pos) -> Bool:
  match a b:
    case Pos{x} Pos{y}:
      U32.is_eq(x, y)

def Pos.n(p: Pos) -> Pos:
  match p:
    case Pos{k}: Pos{U32.sub(k, 1)}

def Pos.s(p: Pos) -> Pos:
  match p:
    case Pos{k}: Pos{U32.add(k, 1)}

def Pos.w(p: Pos) -> Pos:
  match p:
    case Pos{k}: Pos{U32.sub(k, 65536)}

def Pos.e(p: Pos) -> Pos:
  match p:
    case Pos{k}: Pos{U32.add(k, 65536)}

def Pos.nw(p: Pos) -> Pos:
  match p:
    case Pos{k}: Pos{U32.sub(k, 65537)}

def Pos.ne(p: Pos) -> Pos:
  match p:
    case Pos{k}: Pos{U32.add(k, 65535)}

def Pos.sw(p: Pos) -> Pos:
  match p:
    case Pos{k}: Pos{U32.sub(k, 65535)}

def Pos.se(p: Pos) -> Pos:
  match p:
    case Pos{k}: Pos{U32.add(k, 65537)}

def Pos.cardinal_or_same(+a: Pos, +b: Pos) -> Bool:
  Bool.or(
    Pos.eq(a, b),
    Bool.or(
      Pos.eq(Pos.n(a), b),
      Bool.or(
        Pos.eq(Pos.s(a), b),
        Bool.or(Pos.eq(Pos.w(a), b), Pos.eq(Pos.e(a), b))
      )
    )
  )
