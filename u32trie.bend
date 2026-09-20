import Base

# Sparse immutable U32-keyed trie.
#
# Keys are traversed one bit at a time. Since U32's Word representation is
# least-significant-bit first, WCon gives us exactly the next radix bit without
# shifts, strings, hashing, or comparisons.

type Trie is Data:
  Tip{}
  Leaf{value: U32}
  Node{zero: Trie, one: Trie}

# Add delta to one key.
def Trie.add_word(
  n: Nat,
  bits: Word(n),
  delta: U32,
  t: Trie
) -> Trie:
  match n bits t:

    case 0n WNil{} Tip{}:
      Leaf{delta}

    case 0n WNil{} Leaf{value}:
      Leaf{U32.add(value, delta)}

    # Invalid for tries created by this module, but keep the function total.
    case 0n WNil{} Node{zero, one}:
      Node{zero, one}

    case 1n+p WCon{False{}, rest} Tip{}:
      Node{
        Trie.add_word(p, rest, delta, Tip{}),
        Tip{}
      }

    case 1n+p WCon{True{}, rest} Tip{}:
      Node{
        Tip{},
        Trie.add_word(p, rest, delta, Tip{})
      }

    # These Leaf/non-zero-depth cases are unreachable for tries created by
    # Trie.add. They only make the datatype functions total.
    case 1n+p WCon{False{}, rest} Leaf{value}:
      Leaf{U32.add(value, delta)}

    case 1n+p WCon{True{}, rest} Leaf{value}:
      Leaf{U32.add(value, delta)}

    case 1n+p WCon{False{}, rest} Node{zero, one}:
      Node{
        Trie.add_word(p, rest, delta, zero),
        one
      }

    case 1n+p WCon{True{}, rest} Node{zero, one}:
      Node{
        zero,
        Trie.add_word(p, rest, delta, one)
      }

def Trie.add(t: Trie, key: U32, delta: U32) -> Trie:
  match key:
    case U32{bits}:
      Trie.add_word(32n, bits, delta, t)

# Lookup.
def Trie.get_word(
  n: Nat,
  bits: Word(n),
  t: Trie
) -> U32:
  match n bits t:

    case 0n WNil{} Tip{}:
      0

    case 0n WNil{} Leaf{value}:
      value

    case 0n WNil{} Node{zero, one}:
      0

    case 1n+p WCon{False{}, rest} Tip{}:
      0

    case 1n+p WCon{True{}, rest} Tip{}:
      0

    case 1n+p WCon{False{}, rest} Leaf{value}:
      value

    case 1n+p WCon{True{}, rest} Leaf{value}:
      value

    case 1n+p WCon{False{}, rest} Node{zero, one}:
      Trie.get_word(p, rest, zero)

    case 1n+p WCon{True{}, rest} Node{zero, one}:
      Trie.get_word(p, rest, one)

def Trie.get(t: Trie, key: U32) -> U32:
  match key:
    case U32{bits}:
      Trie.get_word(32n, bits, t)

# Pairwise merge. Values at identical keys are summed.
def Trie.merge(a: Trie, b: Trie) -> Trie:
  match a b:

    case Tip{} Tip{}:
      Tip{}

    case Tip{} Leaf{value}:
      Leaf{value}

    case Tip{} Node{zero, one}:
      Node{zero, one}

    case Leaf{value} Tip{}:
      Leaf{value}

    case Node{zero, one} Tip{}:
      Node{zero, one}

    case Leaf{a} Leaf{b}:
      Leaf{U32.add(a, b)}

    case Node{az, ao} Node{bz, bo}:
      z o =
        Trie.merge(az, bz)
        Trie.merge(ao, bo)
      Node{z, o}

    # Unreachable when both operands were created through this module.
    case Leaf{value} Node{zero, one}:
      Node{zero, one}

    case Node{zero, one} Leaf{value}:
      Node{zero, one}
