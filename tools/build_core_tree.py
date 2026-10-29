#!/usr/bin/env python3
"""Assemble the System 11 core source tree for the Pocket build.

Copies references/SYSTEM11_MiSTer, applies the area/timing variants the probe flow settled on (synth/pocket_probe/variants),
the MiSTer-scaffolding stubs, and pocket/core/emu/pocket_emu.apply, then writes core_tree.qip listing what Quartus compiles.
The reference submodule is never modified.

Usage: build_core_tree.py OUTDIR      (run from the repository root)
"""
import os, re, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / "references/SYSTEM11_MiSTer"
VARIANTS = ROOT / "synth/pocket_probe/variants"
ARGS = [str(ROOT / "references/openfpga-PlayStation"), str(ROOT / "references/Laxer-PS-GTE"), str(ROOT / "references/PSX_MiSTer")]

# Same order as the probe runs that measured 18,0xx ALMs / closed clk_2x timing (host-side .apply scripts only).
APPLY = ["gte_laxer", "ps_gte", "ps_patches", "ps_gpu_recip", "gpu_area_reg", "gpu_rect_timing", "gpu_read_late",
         "cpu_execute_share", "c76_sfr_ram", "c76_vblank_irq", "c352_tag_ram", "no_texfilter",
         "drop_scaffold", "savestates_reset_only", "drop_scaffold2", "drop_scaffold3", "gun_pad_aim", "gun_gp1_soft", "eeprom_blank", "s11_bootbits"]


def main():
    out = Path(sys.argv[1]).resolve()
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(REF, out, ignore=shutil.ignore_patterns(".git", "releases", "art", "*.md"))
    (out / "build_id.v").write_text('`define BUILD_DATE "000000"\n')

    skip = set(filter(None, os.environ.get("S11_SKIP", "").split(",")))   # A/B builds: S11_SKIP=cpu_execute_share,...
    apply = [v for v in APPLY if v not in skip]
    for v in apply:
        script = VARIANTS / f"{v}.apply"
        r = subprocess.run([sys.executable, str(script), str(out), *ARGS], cwd=ROOT, capture_output=True, text=True)
        if r.returncode:
            sys.exit(f"{v}.apply failed:\n{r.stdout}\n{r.stderr}")
        print(f"applied {v}: {r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ''}")

    if os.environ.get("S11_NO_MDEC") == "1":      # frees ~600 ALMs (no intro/attract FMVs); used when a debug build does not otherwise fit
        shutil.copy(VARIANTS / "no_mdec.vhd", out / "rtl/mdec.vhd")
        print("applied no_mdec")

    # c76_ram_bram.sh: the 512 B C76 RAM debug taps read it combinationally and stop block-RAM inference; tie them off
    c76 = out / "rtl/c76.vhd"
    t = c76.read_text()
    t, n = re.subn(r"^( *dbg_ram80 *<= )ram\(0\);", r"\1(others => '0');", t, flags=re.M)
    t, m = re.subn(r"^( *dbg_ram83 *<= )ram\(3\);", r"\1(others => '0');", t, flags=re.M)
    assert n == 1 and m == 1, (n, m)
    c76.write_text(t)
    print("applied c76_ram_bram")

    script = ROOT / "pocket/core/emu/pocket_emu.apply"
    r = subprocess.run([sys.executable, str(script), str(out)], cwd=ROOT, capture_output=True, text=True)
    if r.returncode:
        sys.exit(f"pocket_emu.apply failed:\n{r.stdout}\n{r.stderr}")
    print("applied pocket_emu:", r.stdout.strip())

    # probes that must run after pocket_emu.apply (S11_PROBES=s11_ramprobe,...)
    for v in filter(None, os.environ.get("S11_PROBES", "").split(",")):
        r = subprocess.run([sys.executable, str(VARIANTS / f"{v}.apply"), str(out)], cwd=ROOT, capture_output=True, text=True)
        if r.returncode:
            sys.exit(f"{v}.apply failed:\n{r.stdout}\n{r.stderr}")
        print(f"applied {v}")

    (out / "core_tree.qip").write_text(
        'set_global_assignment -name SEARCH_PATH [file join $::quartus(qip_path) .]\n'
        'set_global_assignment -name QIP_FILE [file join $::quartus(qip_path) rtl/psx.qip]\n'
        'set_global_assignment -name QIP_FILE [file join $::quartus(qip_path) rtl/mem.qip]\n'
        'set_global_assignment -name SYSTEMVERILOG_FILE [file join $::quartus(qip_path) rtl/savestate_ui.sv]\n'
        'set_global_assignment -name VERILOG_FILE [file join $::quartus(qip_path) rtl/hps_ext.v]\n'
        'set_global_assignment -name SYSTEMVERILOG_FILE [file join $::quartus(qip_path) sys/video_freak.sv]\n'
        'set_global_assignment -name SYSTEMVERILOG_FILE [file join $::quartus(qip_path) sys/gamma_corr.sv]\n'
        'set_global_assignment -name SYSTEMVERILOG_FILE [file join $::quartus(qip_path) SYSTEM11.sv]\n')
    print("wrote", out / "core_tree.qip")

    # the full-core project revision: the shell project with the full core instead of the skeleton.
    # Only for the real tree: a scratch tree (checks, tests) must not rewrite the .qsf of a compile that may be running.
    if out != (ROOT / "pocket/build/core_tree").resolve():
        print("scratch tree: pocket/project/s11full.qsf left alone")
        return
    proj = ROOT / "pocket/project"
    q = (proj / "s11.qsf").read_text()
    assert q.count("QIP_FILE ../core/core.qip") == 1
    q = q.replace("QIP_FILE ../core/core.qip", "QIP_FILE ../core/core_full.qip")
    q += '\nset_global_assignment -name VERILOG_MACRO "MISTER_FB=1"\nset_global_assignment -name VHDL_INPUT_VERSION VHDL_2008\n'
    # area-first fitter settings: the performance-oriented ones in s11.qsf (physical synthesis, register/logic duplication) cost enough ALMs
    # that the full core does not fit the 5CEBA4 (run 39293097968: 1,867 LABs needed of 1,848); these fit it at 18,260 ALMs
    q += (
        'set_global_assignment -name OPTIMIZATION_MODE "AGGRESSIVE AREA"\n'
        'set_global_assignment -name PHYSICAL_SYNTHESIS_COMBO_LOGIC OFF\n'
        'set_global_assignment -name PHYSICAL_SYNTHESIS_REGISTER_DUPLICATION OFF\n'
        'set_global_assignment -name PHYSICAL_SYNTHESIS_ASYNCHRONOUS_SIGNAL_PIPELINING OFF\n'
        'set_global_assignment -name ROUTER_LCELL_INSERTION_AND_LOGIC_DUPLICATION OFF\n'
        'set_global_assignment -name REMOVE_REDUNDANT_LOGIC_CELLS ON\n'
        # clk_1x -> clk_3x hold (clock skew 0.5 ns > data delay 0.4 ns on the ioctl/ch3 handoff): let the fitter fix hold on all paths
        'set_global_assignment -name OPTIMIZE_HOLD_TIMING "ALL PATHS"\n'
        'set_global_assignment -name OPTIMIZE_MULTI_CORNER_TIMING ON\n')
    (proj / "s11full.qsf").write_text(q)
    print("wrote", proj / "s11full.qsf")


if __name__ == "__main__":
    main()
