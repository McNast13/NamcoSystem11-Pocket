# Namco System 11 for Analogue Pocket (openFPGA)

Port of [SYSTEM11_MiSTer](https://github.com/XelaNotPu/SYSTEM11_MiSTer) (itself derived from
[PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer)) to the Analogue Pocket.

**Status:** experimental. Tekken 1 boots and runs its attract mode on a real Pocket (3D fights render). Not yet playable:
Start is being fixed, some polygons are still missing, and there are no FMVs (MDEC is left out to fit the FPGA, about 98% of its
ALMs used). See [docs/SHELL.md](docs/SHELL.md) for the architecture and the full bring-up log, and
[docs/BASELINE.md](docs/BASELINE.md) for the measurements. **First goal:** playable Tekken 2 (TES3 VER.D / TES2 VER.D).

Build and package: `tools/local_build.sh` (local Quartus in Docker, see [docs/LOCAL_BUILD.md](docs/LOCAL_BUILD.md)) or GitHub
Actions (`pocket-shell.yml` with `project=s11full`). `tools/build_core_tree.py` assembles the source tree, Quartus compiles
`pocket/project/s11full`, `tools/package_pocket.py` makes the SD-card tree, and
`tools/rom_packer.py GAME.mra --roms DIR --out DIR --instance NAME` turns your own MAME ROM zips into the data-slot files and
the instance JSON. No ROMs are included or distributed. Releases are built by `release.yml` when a `v*` tag is pushed.

## Use of AI

This port is being built with heavy use of AI, and we want to be upfront about that.

- **Who does what.** The project is run by McNast13, who sets the goals, makes the decisions, runs every test on a real Pocket
  and reports what the screen shows. Most of the code, scripts, simulations and documentation in this repository were written by
  Claude (Anthropic's AI model) working through Claude Code, under that direction. Commits made this way carry a
  `Co-Authored-By: Claude` line.
- **Upstream code is not rewritten.** The cores this is built on (listed under Credits) are included unmodified as git
  submodules. Every change to them is a small, separate patch script (`synth/pocket_probe/variants/*.apply`) with a comment
  saying what it changes and why, so each one can be read, reviewed, switched off (`S11_SKIP`) or reverted on its own.
- **Evidence before fixes.** Problems are tracked down with measurements rather than guesses: simulations that compare a patched
  block against the original (`tests/`), A/B builds with one change left out, and diagnostic builds that show internal signals as a
  grid on the Pocket's screen, photographed and decoded (`tools/diag_decode_calib.py`). Hypotheses that turned out wrong are kept
  in the log in [docs/SHELL.md](docs/SHELL.md), not deleted.
- **Limits.** AI-written hardware description code can be wrong in ways that compile and fit cleanly. The checks here are
  simulation and testing on hardware, not an expert line-by-line review, so treat the core as experimental. Bug reports and
  reviews from people who know these systems are very welcome.

See [docs/PLAN.md](docs/PLAN.md). Licensed GPL (upstream sources are GPL-2.0/3.0; see LICENSE and upstream notices).

## Credits

- **[GuardianSoul](https://github.com/GuardianSoul)** - author of [openfpga-PlayStation](https://github.com/GuardianSoul/openfpga-PlayStation),
  the PlayStation core for the Analogue Pocket. This port builds directly on his work: the area-reduction patch
  chain (`scripts/prepare_*.py`), the Pocket shell and memory approach, and the proof that a PlayStation-class design can
  fit the Pocket's FPGA. Without it this project would not be feasible.
- **XelaNotPu** - [SYSTEM11_MiSTer](https://github.com/XelaNotPu/SYSTEM11_MiSTer), the Namco System 11 core being ported.
- **MiSTer-devel / Robert Peip (FPGAzumSpass)** - [PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer), the base PlayStation core.
- **Laxer3a** - [PS-GTE](https://github.com/Laxer3a/PS-GTE), the compact GTE used for area reduction.
