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

No ROMs or BIOS files are included. You need your own **current MAME** romsets (zips), the same ones the
[SYSTEM11_MiSTer](https://github.com/XelaNotPu/SYSTEM11_MiSTer) core uses: its MRA files name each set's files and CRCs. Older
romsets (for example MAME 2015) match only where those sets have not changed since; the packer reports any that do not.

- **BIOS:** `c76.bin`, the C76 sound CPU's BIOS from `namcoc76.zip`, shared by every game. It goes in
  `Assets/namco_system11/common/c76.bin` (md5 `8ca155e5ad03571e0930d8d361749b03`).
- **Games:** the core ships a game list of 35 sets (every MRA of the MiSTer core, main versions and alternatives), one instance
  file each in `Assets/namco_system11/McNast13.NamcoSystem11/`. Each names the files its game needs in
  `Assets/namco_system11/common/<MAME set name>/`, so **pupdate** and **Pocket Sync** list them as the core's required files and show
  which are missing. Only Tekken (Asia, TE4/VER.C) and Tekken 2 Ver.B (US, TES3/VER.D) have been tested on a Pocket so far.

| Game | Current MAME sets |
|---|---|
| Tekken | `tekken` (TE2/VER.C), `tekkenac`, `tekkenb`, `tekkenjb` |
| Tekken 2 | `tekken2` (TES2/VER.D), `tekken2ud`, `tekken2ub`, `tekken2b`, `tekken2a`, `tekken2ua`, `tekken2jb`, `tekken2jc` |
| Soul Edge | `souledge` (Ver. II, SO4/VER.C), `souledgeuc`, `souledgea`, `souledgeua`, `souledgeja` |
| Xevious 3D/G | `xevi3dg`, `xevi3dga`, `xevi3dgj` |
| Dancing Eyes | `danceyes`, `danceyesu`, `danceyesj` |
| Dunk Mania | `dunkmnia`, `dunkmniajc` |
| Point Blank 2 / Gunbarl | `ptblank2a`, `ptblank2b`, `ptblank2c`, `ptblank2ua`, `gunbarla` |
| Star Sweep | `starswep`, `starswepj` |
| Pocket Racer, Prime Goal EX, Kosodate Quiz My Angel 3 | `pocketrc`, `primglex`, `myangel3` |

A clone set (for example `tekkenac`) also reads its parent's zip (`tekken.zip`), as in MAME; a merged parent zip that contains the
clone's files is enough.

### Installing games

The Pocket cannot read MAME zips, so the game files are built once on a computer (Python 3 needed) with `tools/make_games.py`, which
follows each set's MRA and checks every file's CRC:

1. Clone this repository with the MiSTer core submodule (it holds the MRA files):
   ```
   git clone https://github.com/McNast13/NamcoSystem11-Pocket
   cd NamcoSystem11-Pocket
   git submodule update --init references/SYSTEM11_MiSTer
   ```
2. Put your romset zips and `namcoc76.zip` in one folder, for example `~/roms`.
3. Build every game it finds there straight onto the SD card (or into a folder you copy to the card's root):
   ```
   python3 tools/make_games.py --roms ~/roms --sd /Volumes/<your SD card>
   ```
   It writes `Assets/namco_system11/common/c76.bin`, one `common/<set>/` folder per game, and that game's instance file with the
   files' MD5s, and lists the sets it found no (or no matching) zip for.
4. On the Pocket, open **Namco System 11** and pick the game from the list.

**Switching games:** quit the core (Pocket menu > Quit) and open it again, then pick the next game. There is no "Load game" entry in
the core's settings, as in the PlayStation core: loading a new game into the running core does not restart these boards cleanly,
so the core is always started fresh for each game.

Game settings (the EEPROM) start blank at every launch for now, so changes made in the game's test menu are not kept yet.

## Building

To build and package, use `tools/local_build.sh` (local Quartus in Docker, see [docs/LOCAL_BUILD.md](docs/LOCAL_BUILD.md)) or GitHub
Actions (`pocket-shell.yml` with `project=s11full`). `tools/build_core_tree.py` assembles the source tree, Quartus compiles
`pocket/project/s11full`, `tools/package_pocket.py` makes the SD-card tree, and
`tools/make_games.py` turns your own MAME ROM zips into the game files and the game list (`tools/rom_packer.py` packs one MRA). No ROMs are included or distributed. Releases are built by `release.yml` when a `v*` tag is pushed.

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
