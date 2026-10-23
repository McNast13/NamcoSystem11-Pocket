#!/usr/bin/env bash
# Local Quartus build, mirrors .github/workflows/pocket-shell.yml (same image: raetro/quartus:pocket, Quartus 18.1 Lite).
# Runs the amd64 image under Rosetta via OrbStack. See docs/LOCAL_BUILD.md.
#
# usage: tools/local_build.sh [project] [label]            e.g. tools/local_build.sh s11full test1
# env:   S11_NO_MDEC=1        drop MDEC (same as the workflow's no_mdec input)
#        QSF_EXTRA='line\nline'  extra QSF lines appended to <project>.qsf (workflow's qsf_extra input)
#        S11_SKIP=a,b          omit those variants (A/B builds)
#        S11_PROBES=a,b        extra probe variants applied after pocket_emu.apply (e.g. s11_ramprobe)
#        QUARTUS_CPUS=n        parallel compile processors (default 2; lower if the fitter runs out of memory)
set -euo pipefail
cd "$(dirname "$0")/.."

project=${1:-s11full}
label=${2:-local}
image=raetro/quartus:pocket
out=pocket/project/output_files
qsf=pocket/project/$project.qsf

command -v docker >/dev/null || { echo "docker not found (install OrbStack)"; exit 1; }
docker info >/dev/null 2>&1 || { echo "docker daemon not running (open OrbStack)"; exit 1; }

git submodule update --init --depth 1 references/SYSTEM11_MiSTer references/openfpga-PlayStation \
  references/Laxer-PS-GTE references/PSX_MiSTer

if [ "$project" = s11full ]; then
  S11_NO_MDEC=${S11_NO_MDEC:-0} python3 tools/build_core_tree.py pocket/build/core_tree
fi

# keep the tracked qsf pristine: experiments go into a temp revision-independent backup/restore
cp "$qsf" "$qsf.orig"
trap 'mv -f "$qsf.orig" "$qsf"' EXIT
printf '\nset_global_assignment -name NUM_PARALLEL_PROCESSORS %s\n' "${QUARTUS_CPUS:-2}" >> "$qsf"
if [ -n "${QSF_EXTRA:-}" ]; then printf '\n%b\n' "$QSF_EXTRA" >> "$qsf"; fi

rm -rf "$out"
start=$(date +%s)
docker run --rm --platform linux/amd64 -v "$PWD/pocket:/pocket" -w /pocket/project "$image" \
  sh -c "quartus_sh --flow compile $project; quartus_sta -t report_paths.tcl $project" | tee "build-$label.log" || true
echo "elapsed: $(( $(date +%s) - start )) s"

cat "$out"/*.fit.summary 2>/dev/null || echo "no fit summary (build failed?)"
if [ "$project" != s11 ] && ls "$out"/*.rbf >/dev/null 2>&1; then
  python3 tools/package_pocket.py --rbf "$out/$project.rbf" --out "pocket/package-$label"
  echo "package: pocket/package-$label"
fi
