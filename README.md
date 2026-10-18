# Namco System 11 for Analogue Pocket (openFPGA)

Port of [SYSTEM11_MiSTer](https://github.com/XelaNotPu/SYSTEM11_MiSTer) (itself derived from
[PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer)) to the Analogue Pocket.

**Status:** planning. **First goal:** playable Tekken 2 (TES2-VER.D).

See [docs/PLAN.md](docs/PLAN.md). Licensed GPL (upstream sources are GPL-2.0/3.0; see LICENSE and upstream notices).

## Credits

- **[GuardianSoul](https://github.com/GuardianSoul)** - author of [openfpga-PlayStation](https://github.com/GuardianSoul/openfpga-PlayStation),
  the PlayStation core for the Analogue Pocket. This port builds directly on his work: the area-reduction patch
  chain (`scripts/prepare_*.py`), the Pocket shell and memory approach, and the proof that a PlayStation-class design can
  fit the Pocket's FPGA. Without it this project would not be feasible.
- **XelaNotPu** - [SYSTEM11_MiSTer](https://github.com/XelaNotPu/SYSTEM11_MiSTer), the Namco System 11 core being ported.
- **MiSTer-devel / Robert Peip (FPGAzumSpass)** - [PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer), the base PlayStation core.
- **Laxer3a** - [PS-GTE](https://github.com/Laxer3a/PS-GTE), the compact GTE used for area reduction.
