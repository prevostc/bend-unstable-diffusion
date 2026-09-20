import Base
import ./pos.bend as P
import ./parse.bend as Parse
import ./sim.bend as Sim

def Input.read_ok(file: File, text: String) -> IO(String):
  do IO<String>:
    u : Unit <- File.close(file)
    return text

def Input.read_fail(
  file: File,
  err: U32 & String
) -> IO(String):
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

    Input.read_result(pair)

def Input.run(
  parsed: Maybe<&2, Sim.Batch<P.Pos>>
) -> IO(Unit):
  match parsed:
    case None{}:
      IO.die(Unit, 1, "input contains no elves")

    case Some{agents}:
      +result = Sim.run(10n, agents, Sim.P0{})

      IO.print(
        "elves after 10 rounds: "
        ++ Nat.show(Sim.Batch.size(P.Pos, result))
      )

def Input.main_args(args: List<String>) -> IO(Unit):
  match args:
    case Nil{}:
      IO.die(Unit, 1, "usage: bend main.bend input.txt")

    case path <> rest:
      do IO<Unit>:
        text : String <- Input.read(path)

        Input.run(
          Sim.Batch.from_list(
            Parse.Parse.positions(text)
          )
        )

def Input.main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    Input.main_args(args)
