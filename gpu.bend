import Base
import ./main.bend as Sim

# GPU entrypoint for a CUDA-capable remote machine.
# GitHub Codespaces itself does not provide an NVIDIA GPU.
def main() -> IO(Unit):
  result = Sim.run!(3n, Sim.sample(), Sim.P0{})
  IO.print("elves after 3 GPU rounds: " ++ Nat.show(Sim.Batch.size(Sim.Pos, result)))
