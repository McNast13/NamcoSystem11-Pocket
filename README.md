# Namco System 11 for Analogue Pocket (openFPGA)

Port of [SYSTEM11_MiSTer](https://github.com/XelaNotPu/SYSTEM11_MiSTer) (itself derived from
[PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer)) to the Analogue Pocket.

**Status:** experimental, **not yet run on hardware**. The full core plus Pocket shell compiles and fits the Pocket's FPGA
(5CEBA4F23C8, about 99% of its ALMs, MDEC/FMVs included); see [docs/SHELL.md](docs/SHELL.md) for the architecture and
[docs/BASELINE.md](docs/BASELINE.md) for the measurements. **First goal:** playable Tekken 2 (TES3 VER.D / TES2 VER.D).

Build and package (GitHub Actions does this, `pocket-shell.yml` with `project=s11full`): `tools/build_core_tree.py` assembles the
source tree, Quartus compiles `pocket/project/s11full`, `tools/package_pocket.py` makes the SD-card tree, and
`tools/rom_packer.py GAME.mra --roms DIR --out DIR --instance NAME` turns your own MAME ROM zips into the data-slot files and
the instance JSON. No ROMs are included or distributed.

See [docs/PLAN.md](docs/PLAN.md). Licensed GPL (upstream sources are GPL-2.0/3.0; see LICENSE and upstream notices).

## Credits

- **[GuardianSoul](https://github.com/GuardianSoul)** - author of [openfpga-PlayStation](https://github.com/GuardianSoul/openfpga-PlayStation),
  the PlayStation core for the Analogue Pocket. This port builds directly on his work: the area-reduction patch
  chain (`scripts/prepare_*.py`), the Pocket shell and memory approach, and the proof that a PlayStation-class design can
  fit the Pocket's FPGA. Without it this project would not be feasible.
- **XelaNotPu** - [SYSTEM11_MiSTer](https://github.com/XelaNotPu/SYSTEM11_MiSTer), the Namco System 11 core being ported.
- **MiSTer-devel / Robert Peip (FPGAzumSpass)** - [PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer), the base PlayStation core.
- **Laxer3a** - [PS-GTE](https://github.com/Laxer3a/PS-GTE), the compact GTE used for area reduction.
