# Namco System 11 for Analogue Pocket (openFPGA)

Port of [SYSTEM11_MiSTer](https://github.com/XelaNotPu/SYSTEM11_MiSTer) (itself derived from
[PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer)) to the Analogue Pocket.

**Status:** experimental. Latest release: [v0.1.2](https://github.com/McNast13/NamcoSystem11-Pocket/releases/latest).
Tested as working on a real Pocket: Tekken, Tekken 2, Soul Edge, Prime Goal EX, Pocket Racer, Kosodate Quiz My Angel 3, Dancing
Eyes and Xevious 3D/G. Dunk Mania, Point Blank 2 and Star Sweep have not been tested yet. The design uses about 98% of the FPGA
(18,089 / 18,480 ALMs). See [docs/SHELL.md](docs/SHELL.md) for the architecture and the full bring-up log, and
[docs/BASELINE.md](docs/BASELINE.md) for the measurements.

What the core has so far:

- The System 11 board on the PlayStation core: R3000 CPU, GPU, GTE and MDEC (the FMV decoder, which the games also need to
  accept Start), with the GPU/GTE/DMA fixes from version 0.5.6 of the PlayStation core.
- VRAM in the Pocket's PSRAM at full rate, so the GPU finishes every frame (this fixed polygons and HUD parts that dropped out).
- The C76 sound CPU with its BIOS, interrupted on vertical blank as on the board.
- A game list of 35 sets built from your own MAME romsets, with each game's required files listed for pupdate and Pocket Sync.

Known limitations:

- To change game, quit the core and open it again (there is no "Load game").
- Game settings (the EEPROM) are not kept between launches yet.
- A thin line can show at the top of the picture.
- Not every regional version in `_alternatives` has been tried.

## Installing

### The core

1. Get `NamcoSystem11-pocket-core-<version>.zip` from this repository's
   [Releases](https://github.com/McNast13/NamcoSystem11-Pocket/releases) page (or build it yourself, see [Building](#building)).
2. Unzip it onto the root of the Pocket's SD card. It adds `Cores/McNast13.NamcoSystem11/`, `Platforms/namco_system11.json` (with
   the platform banner), the game list in `Assets/namco_system11/McNast13.NamcoSystem11/` and an empty
   `Assets/namco_system11/common/` with a README saying which files go there. No ROMs are included.
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
  which are missing. The main version of each game (the MRAs at the top of the MiSTer core's `_Arcade` folder, first in each row
  below) is at the top of the list; the other versions are in an `_alternatives` subfolder (pupdate's "skip alternative assets"
  setting skips it). The **Tested** column shows the games confirmed working on a Pocket.

| Game | Current MAME sets | Tested |
|---|---|---|
| Tekken | `tekken` (TE2/VER.C), `tekkenac`, `tekkenb`, `tekkenjb` | Yes |
| Tekken 2 | `tekken2` (TES2/VER.D), `tekken2ud`, `tekken2ub`, `tekken2b`, `tekken2a`, `tekken2ua`, `tekken2jb`, `tekken2jc` | Yes |
| Soul Edge | `souledge` (Ver. II, SO4/VER.C), `souledgeuc`, `souledgea`, `souledgeua`, `souledgeja` | Yes |
| Xevious 3D/G | `xevi3dg`, `xevi3dga`, `xevi3dgj` | Yes |
| Dancing Eyes | `danceyes`, `danceyesu`, `danceyesj` | Yes |
| Dunk Mania | `dunkmnia`, `dunkmniajc` | Not yet |
| Point Blank 2 / Gunbarl | `ptblank2a`, `ptblank2b`, `ptblank2c`, `ptblank2ua`, `gunbarla` | Not yet |
| Star Sweep | `starswep`, `starswepj` | Not yet |
| Pocket Racer, Prime Goal EX, Kosodate Quiz My Angel 3 | `pocketrc`, `primglex`, `myangel3` | Yes (all three) |

A clone set (for example `tekkenac`) also reads its parent's zip (`tekken.zip`), as in MAME; a merged parent zip that contains the
clone's files is enough.

### Files each main version needs

The zip and files below are exactly what `tools/make_games.py` checks (from each set's MRA); the CRC identifies the file, so
a file with the right CRC is accepted whatever it is named. Every game also needs `c76.bin` (CRC `399faac7`, md5 `8ca155e5ad03571e0930d8d361749b03`) from `namcoc76.zip`.
The other versions in `_alternatives` are listed in their MRAs (`references/SYSTEM11_MiSTer/releases/_Arcade/_alternatives`).

| Game (main version) | MAME zip | Files (CRC) | Installed to `common/` |
|---|---|---|---|
| Dancing Eyes (DC2/VER.B) | `danceyes.zip` | `dc2verb.2l` 9f605dd9<br>`dc2verb.2j` 210d7e22<br>`dc1vera.2k` bdd9484e<br>`dc1vera.2f` 25a2f06f<br>`dc1rom0l.ic5` 8b5b4b13<br>`dc1rom0u.ic6` 93ca9bd0<br>`dc1rom1l.ic3` 380e0282<br>`dc1rom1u.ic8` 47d966a7<br>`dc1rom2l.ic4` 8f130220<br>`dc1rom2u.ic7` 24514dc6<br>`dc1rom3l.ic1` a76bcd4c<br>`dc1rom3u.ic9` 1405d123<br>`dc1sprog.6d` 96cd7788<br>`dc1wave.8k` 8ba0f6a7 | `danceyes/` |
| Dunk Mania (DM2/VER.C) | `dunkmnia.zip` | `dm2verc.2l` f6a6c46e<br>`dm2verc.2j` 1df539ce<br>`dm1verc.2k` c8d72f78<br>`dm1verc.2f` d379dfa9<br>`dm1rom0l.ic5` 4bb5d71d<br>`dm1rom0u.ic6` c16b47c5<br>`dm1rom1l.ic3` 20dd3294<br>`dm1rom1u.ic8` 01e905d3<br>`dm1sprog.6d` de1cbc78<br>`dm1wave.8k` 883d7455 | `dunkmnia/` |
| Kosodate Quiz My Angel 3 (KQT1/VER.A) | `myangel3.zip` | `kqt1vera.1j` df7aef8a<br>`kqt1vera.1l` ffc51c01<br>`kqt1prg0l.ic2` d67eee66<br>`kqt1prg0u.ic5` 4d1c7bf3<br>`kqt1prg1l.ic3` 298d8eeb<br>`kqt1prg1u.ic6` 911783db<br>`kqt1sprog.7e` bb1888a6<br>`kqt1wave.8k` 92ca8e4f | `myangel3/` |
| Pocket Racer (PKR1/VER.B) | `pocketrc.zip` | `pkr1verb.2l` 300d906a<br>`pkr1verb.2j` d5f47526<br>`pkr1rom0l.ic5` 6c9b074c<br>`pkr1rom0u.ic6` a55c0906<br>`pkr1verb.6d` 9bf08992<br>`pkr1wave.8k` 72517c46 | `pocketrc/` |
| Point Blank 2 (World, GNB2/VER.A) | `ptblank2a.zip` or `ptblank2.zip` | `gnb2vera.2l` 4926599d<br>`gnb2vera.2j` 2aba8c09<br>`gnb1vera.2k` e6335e4e<br>`gnb1vera.2f` 2bb7eb6d<br>`gnb2prg.1` 8a8e77c3<br>`gnb2prg.2` 563edc3f<br>`gnb2prg.3` 94fbe733<br>`gnb2prg.4` 1cbe79a6<br>`gnb1vera.6d` 6461ae77<br>`gnb1wave.8k` 4e19d9d6 | `ptblank2a/` |
| Prime Goal EX (PG1/VER.A) | `primglex.zip` | `pg1vera.2l` fc15fd1a<br>`pg1vera.2j` 79955553<br>`pg1rom0u.ic5` 2a503f2f<br>`pg1rom0l.ic6` 54cef992<br>`pg1rom1u.ic3` 1ee41152<br>`pg1rom1l.ic8` 59b5a71c<br>`pg1sprog.6d` e7c3396d<br>`pg1wave.8k` fc9ad9eb | `primglex/` |
| Soul Edge Ver. II (SO4/VER.C) | `souledge.zip` | `so4verc.2l` 12b8ae0d<br>`so4verc.2j` 938262b0<br>`so1verc.2k` 1789e399<br>`so1verc.2f` 8cffe1c3<br>`so1rom0u.ic5` e364d673<br>`so1rom0l.ic6` 9c5b0858<br>`so1rom1u.ic3` 8f9d8c5b<br>`so1rom1l.ic8` 4406ef16<br>`so1rom2u.ic4` b4baa886<br>`so1rom2l.ic7` 37c1f66e<br>`so1rom3u.ic1` f11bd521<br>`so1rom3l.ic9` 84465bcc<br>`so1sprogc.6d` 2bbc118c<br>`so1wave.8k` 0e68836b | `souledge/` |
| Star Sweep (STP1/VER.A) | `starswep.zip` | `stp2vera.2l` a03f4bac<br>`stp2vera.2j` 590da032<br>`stp2vera.2k` ac8717d5<br>`stp2vera.2f` 42733309<br>`stp2vera.6d` 08aaaf6a<br>`stp1wave.8k` 18f30e92 | `starswep/` |
| Tekken (TE2/VER.C) | `tekken.zip` | `te2verc.2l` a24c8c57<br>`te2verc.2j` 3224c298<br>`te1verb.2k` b9860b29<br>`te1verb.2f` 3dc01aad<br>`te1rom0l.ic5` 03786e09<br>`te1rom0u.ic6` 75d91051<br>`te1rom1l.ic3` 81416f8e<br>`te1rom1u.ic8` fa7ba433<br>`te1rom2l.ic4` 41d77846<br>`te1rom2u.ic7` a678987e<br>`te1sprog.6d` 849587e9<br>`te1wave.8k` fce6c57a | `tekken/` |
| Tekken 2 Ver.B (TES2/VER.D) | `tekken2.zip` | `tes2verd.2l` 1aef3da8<br>`tes2verd.2j` 03787fd0<br>`tes1verd.2k` 846ace0a<br>`tes1verd.2f` 7a0663b4<br>`tes1rom0l.ic6` fc904ede<br>`tes1rom0u.ic5` 57b38f5d<br>`tes1rom1l.ic8` aa48f04b<br>`tes1rom1u.ic3` b147c543<br>`tes1rom2l.ic7` b08da52c<br>`tes1rom2u.ic4` 8a1561b8<br>`tes1rom3l.ic9` d5ac0f18<br>`tes1rom3u.ic1` 44ed509d<br>`tes1sprog.6d` af18759f<br>`tes1wave.8k` 34a34eab | `tekken2/` |
| Xevious 3D/G (XV32/VER.B) | `xevi3dg.zip` | `xv32verb.2l` 6ffcceac<br>`xv32verb.2j` c096dd18<br>`xv31vera.2k` 3d58138e<br>`xv31vera.2f` 9e8780a2<br>`xv31rom0l.ic5` 24e1e262<br>`xv31rom0u.ic6` cae38ef3<br>`xv31rom1l.ic3` 46b4cb72<br>`xv31rom1u.ic8` be0eb5d1<br>`xv31rom2l.ic4` 8403a277<br>`xv31rom2u.ic7` ecf70432<br>`xv31sprog.6d` e50b856a<br>`xv31wave.8k` 14f25ddd | `xevi3dg/` |

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
`tools/make_games.py` turns your own MAME ROM zips into the game files and the game list (`tools/rom_packer.py` packs one MRA). No ROMs are included or distributed. Releases are built by `release.yml` (push a `v*` tag, or run it by hand from the Actions tab with a tag name): it builds the game
core at the fitter seed of the build tested on a Pocket (seed 22 since v0.1.1), stamps the version into `core.json` and publishes
the release with the SD-card zip. Another seed is the same design but an untested fit, so a new seed is only released after it has
been tested on a Pocket.

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
