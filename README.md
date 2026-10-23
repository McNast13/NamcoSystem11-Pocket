# Namco System 11 for Analogue Pocket (openFPGA)

Port of [SYSTEM11_MiSTer](https://github.com/XelaNotPu/SYSTEM11_MiSTer) (itself derived from
[PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer)) to the Analogue Pocket.

**Status:** experimental. Tekken (Asia, TE4 Ver.C) is playable on a real Pocket: intro FMV, credits, player select and fights.
Some polygons still drop out at some angles, and the design uses about 98% of the FPGA. No other game has been tested on the Pocket
yet. See [docs/SHELL.md](docs/SHELL.md) for the architecture and the full bring-up log, and
[docs/BASELINE.md](docs/BASELINE.md) for the measurements. **Next goal:** playable Tekken 2 (TES3 VER.D / TES2 VER.D).

## Installing

### The core

1. Get the core zip from this repository's [Releases](https://github.com/McNast13/NamcoSystem11-Pocket/releases) page (none yet;
   until then, build it yourself as described under [Building](#building)).
2. Unzip it onto the root of the Pocket's SD card. It adds `Cores/McNast13.NamcoSystem11/` and `Platforms/namco_system11.json`.
3. The core appears in the Pocket's **openFPGA > Arcade Multi** menu as **Namco System 11**.

### BIOS and ROM files

No ROMs or BIOS files are included. You need your own MAME ROM sets (as zips):

| Game | MAME zip(s) | MRA file (in the SYSTEM11_MiSTer submodule) |
|---|---|---|
| Tekken (Asia TE4 Ver.C), **tested** | `tekken.zip` (merged set containing the `tekkenac` files) | `releases/_Arcade/_alternatives/_Tekken/Tekken (Asia TE4 Ver.C).mra` |
| Tekken (TE2 Ver.C) | `tekken.zip` | `releases/_Arcade/Tekken (TE2 Ver.C).mra` |
| Tekken 2 Ver.B (TES2-VER.D) | `tekken2.zip` | `releases/_Arcade/Tekken 2 Ver.B (TES2-VER.D).mra` |
| Soul Edge Ver. II, Dunk Mania, Xevious 3D-G, Prime Goal EX, Star Sweep, Dancing Eyes, Pocket Racer, Point Blank 2, My Angel 3 | the MAME zip named in each MRA | `releases/_Arcade/*.mra` |

Every game also needs the **C76 sound CPU BIOS**, `namcoc76.zip` (it contains `c76.bin`). The MRA files name the exact files and
CRCs; the packer checks every CRC and stops if one is wrong or missing, so a mismatched or incomplete zip is reported, not loaded.
The MRA files come from the [SYSTEM11_MiSTer](https://github.com/XelaNotPu/SYSTEM11_MiSTer) core this port is based on.

### Installing a game

The Pocket cannot read MAME zips directly, so each game is converted once on a computer (Python 3 needed):

1. Clone this repository with the MiSTer core submodule:
   ```
   git clone https://github.com/McNast13/NamcoSystem11-Pocket
   cd NamcoSystem11-Pocket
   git submodule update --init references/SYSTEM11_MiSTer
   ```
2. Put the game's zip and `namcoc76.zip` in one folder, for example `~/roms`.
3. Run the packer with the game's MRA, the ROM folder, an output folder and a short name for the game:
   ```
   python3 tools/rom_packer.py "references/SYSTEM11_MiSTer/releases/_Arcade/_alternatives/_Tekken/Tekken (Asia TE4 Ver.C).mra" \
       --roms ~/roms --out ~/packed/tekken1 --instance tekken1
   ```
   This writes `tekken1.json` and the `rom_*.bin` files into `~/packed/tekken1`.
4. Copy them to the SD card:
   - `tekken1.json` into `Assets/namco_system11/common/`
   - the `rom_*.bin` files into `Assets/namco_system11/common/tekken1/` (a folder named after the game)
5. On the Pocket, open **Namco System 11** and pick the game from the list.

Game settings (the EEPROM) start blank at every launch for now, so changes made in the game's test menu are not kept yet.

## Building

To build and package, use `tools/local_build.sh` (local Quartus in Docker, see [docs/LOCAL_BUILD.md](docs/LOCAL_BUILD.md)) or GitHub
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
