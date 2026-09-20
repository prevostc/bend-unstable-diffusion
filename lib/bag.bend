import Base

# Sparse immutable U32 -> U32 bag.
type Bag is Data:
  Empty{}
  Node{value: U32, zero: Bag, one: Bag}

def Bag.add_word(
  n: Nat,
  bits: Word(n),
  delta: U32,
  bag: Bag
) -> Bag:
  match n bits bag:
    case 0n WNil{} Empty{}:
      Node{delta, Empty{}, Empty{}}

    case 0n WNil{} Node{value, zero, one}:
      Node{U32.add(value, delta), zero, one}

    case 1n+p WCon{False{}, rest} Empty{}:
      Node{
        0,
        Bag.add_word(p, rest, delta, Empty{}),
        Empty{}
      }

    case 1n+p WCon{True{}, rest} Empty{}:
      Node{
        0,
        Empty{},
        Bag.add_word(p, rest, delta, Empty{})
      }

    case 1n+p WCon{False{}, rest} Node{value, zero, one}:
      Node{
        value,
        Bag.add_word(p, rest, delta, zero),
        one
      }

    case 1n+p WCon{True{}, rest} Node{value, zero, one}:
      Node{
        value,
        zero,
        Bag.add_word(p, rest, delta, one)
      }

def Bag.add(bag: Bag, key: U32, delta: U32) -> Bag:
  match key:
    case U32{bits}:
      Bag.add_word(32n, bits, delta, bag)

def Bag.get_word(
  n: Nat,
  bits: Word(n),
  bag: Bag
) -> U32:
  match n bits bag:
    case 0n WNil{} Empty{}:
      0

    case 0n WNil{} Node{value, zero, one}:
      value

    case 1n+p WCon{False{}, rest} Empty{}:
      0

    case 1n+p WCon{True{}, rest} Empty{}:
      0

    case 1n+p WCon{False{}, rest} Node{value, zero, one}:
      Bag.get_word(p, rest, zero)

    case 1n+p WCon{True{}, rest} Node{value, zero, one}:
      Bag.get_word(p, rest, one)

def Bag.get(bag: Bag, key: U32) -> U32:
  match key:
    case U32{bits}:
      Bag.get_word(32n, bits, bag)

def Bag.has(+bag: Bag, key: U32) -> Bool:
  U32.is_ne(Bag.get(bag, key), 0)

def Bag.merge(a: Bag, b: Bag) -> Bag:
  match a b:
    case Empty{} x:
      x

    case x Empty{}:
      x

    case Node{av, az, ao} Node{bv, bz, bo}:
      z o =
        Bag.merge(az, bz)
        Bag.merge(ao, bo)

      Node{U32.add(av, bv), z, o}
