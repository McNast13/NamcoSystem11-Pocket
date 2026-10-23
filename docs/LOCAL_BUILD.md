# Local Quartus build (Apple Silicon)

The GitHub workflow compiles in the Docker image `raetro/quartus:pocket` (Quartus 18.1 Lite, amd64 only). The local build uses the same image, so fits and timing should match the Actions results for the same sources and seed.

## One-time setup
1. OrbStack (provides Docker and Rosetta for amd64 images): `brew install orbstack`, then open it once.
2. Memory: OrbStack > Settings > System > Memory limit, set to about 12 GB (default is dynamic; raise the cap if the fitter is killed).
3. Pull the image (about 6 GB, one time): `docker pull --platform linux/amd64 raetro/quartus:pocket`
4. Disk: the image plus a build need roughly 15 GB free.

## Run
```
tools/local_build.sh s11full mytest        # full core, log in build-mytest.log
S11_NO_MDEC=1 tools/local_build.sh s11full nomdec
QSF_EXTRA='set_global_assignment -name SEED 3' tools/local_build.sh s11full seed3
QUARTUS_CPUS=1 tools/local_build.sh s11full lowmem   # if the fitter runs out of memory
S11_SKIP=cpu_execute_share tools/local_build.sh s11full ab   # A/B: leave a variant out
S11_PROBES=s11_ramprobe tools/local_build.sh s11full probe  # probe variants applied after pocket_emu.apply
```
Diagnostic builds for the Pocket need `S11_NO_MDEC=1` and `QSF_EXTRA` with `SEED 99`, `VERILOG_MACRO "S11_POSEDGE_OUT=1"` and `VERILOG_MACRO "S11_FORCE_DIAG=1"` (see docs/SHELL.md).
Outputs: reports and `paths.*` in `pocket/project/output_files/`, SD-card tree in `pocket/package-<label>` (copy to the Pocket as for the Actions package). The tracked `.qsf` is restored after the run.

## Notes
- Speed: a full s11full compile takes ~16 min on an M4 (16 GB, OrbStack memory limit 12 GB), faster than the Actions runner (~22 min).
- To compare with Actions, use the same `qsf_extra` and seed; Quartus results are seed-sensitive, and the design is at 99% ALMs.
- Free local debugging before any build: iverilog and `nvc` simulations (tests/, tools/s11sim).
