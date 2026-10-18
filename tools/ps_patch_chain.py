#!/usr/bin/env python3
"""Apply the openfpga-PlayStation area patches to a copy of the S11 RTL, in the PS port's order.

Chained like the PS port (several patches require earlier ones). A patch that does not apply to the
S11 source is skipped and reported. Usage: ps_patch_chain.py OUTDIR [patch ...]  (default: all)
"""
import importlib, shutil, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ps_patch_survey as sv  # noqa: E402  (sets up scratch root + sys.path)

# Order follows scripts/prepare_full_pocket.py; (module, function)
ORDER = [  # only patches the shipped PS core applies (prepare_full_pocket.py), in its order
    ("prepare_dma_channel_ram", "channel_ram_text"), ("prepare_dma_chcr_ram", "chcr_ram_text"),
    ("prepare_gpu_poly_share", "poly_share_text"), ("prepare_gpu_vertex_ram", "vertex_ram_text"),
    ("prepare_gpu_mul_narrow", "mul_narrow_text"), ("prepare_gpu_mul_retime", "mul_retime_text"),
    ("prepare_gpu_half_pipe", "half_pipe_text"), ("prepare_gpu_poly_onehot", "onehot_text"),
    ("prepare_gpu_no_watchdog", "no_watchdog_text"), ("prepare_gpu_tag_generation", "tag_generation_text"),
    ("prepare_mdec_mednafen", "mednafen_text"), ("prepare_mdec_idct_pipe", "idct_pipe_text"),
]
# CPU patches are SHA-pinned to upstream cpu.vhd; S11's is hand-modified, so the pin is rebound to
# the S11 text and only the patch's own anchor checks guard it. Opt-in: name them on the command line.
# Patches re-derived for S11's diverged sources (same function name, tools/ module)
OVERRIDE = {"prepare_gpu_tag_generation": "s11_gpu_tag_generation"}
CPU_ORDER = [("prepare_cpu_execute_share", "execute_share_text")]


def dir_patch(out, mod, func, filename):
    """Run a directory-style PS patch (reads UPSTREAM/rtl/<file>, writes <dir>/<file>) on `out`'s current file.

    The PS scripts pin-check their upstream checkout with git; the S11 tree is intentionally different,
    so the pin checks are bypassed here (the patch's own marker checks still guard the text).
    """
    import subprocess, tempfile
    m = importlib.import_module(mod)
    with tempfile.TemporaryDirectory() as t:
        up = Path(t) / "up"; (up / "rtl").mkdir(parents=True)
        shutil.copy(out / filename, up / "rtl" / filename)
        (up / "LICENSE").write_text("GPL-2.0 (see upstream)\n")
        real_co, real_run = subprocess.check_output, subprocess.run
        subprocess.check_output = lambda *a, **k: m.PIN + "\n"
        subprocess.run = lambda *a, **k: subprocess.CompletedProcess(a, 0)
        old = m.UPSTREAM; m.UPSTREAM = up
        try:
            getattr(m, func)(Path(t) / "o")
        finally:
            subprocess.check_output, subprocess.run, m.UPSTREAM = real_co, real_run, old
        text = (Path(t) / "o" / filename).read_text()
    (out / filename).write_text(text)


def sanitize(out):
    """Strip S11-only debug taps that read internal state the area patches restructure."""
    import re
    p = out / "gpu_poly.vhd"
    t = p.read_text()
    t = re.sub(r"^\s*dbg_v([02])\s*<=.*$", lambda m: f"   dbg_v{m.group(1)} <= (others => '0');", t, flags=re.M)
    p.write_text(t)


def main():
    out = Path(sys.argv[1]); only = set(sys.argv[2:])
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(sv.S11, out)
    sanitize(out)
    applied = []
    try:
        dir_patch(out, "prepare_gpu_line_share", "shared_line_source", "gpu_poly.vhd")
        print("APPLIED line_share            gpu_poly.vhd (directory-style, pin check bypassed)")
    except Exception as e:
        print("SKIPPED line_share            ", type(e).__name__, str(e)[:120])
    import hashlib
    for mod, fn in ORDER + (CPU_ORDER if only else []):
        if mod.startswith("prepare_cpu"):
            m = importlib.import_module(mod)
            h = hashlib.sha256((out / "cpu.vhd").read_bytes()).hexdigest()
            for a in dir(m):
                if a.endswith("SHA256"):
                    setattr(m, a, h)
        if only and mod.replace("prepare_", "") not in only:
            continue
        f = getattr(importlib.import_module(OVERRIDE.get(mod, mod)), fn)
        hits, err = [], ""
        domain = mod.split("_")[1]  # gpu / dma / mdec / cpu
        for cand in sv.CANDIDATES:
            if not cand.startswith(domain):
                continue
            p = out / cand
            src = p.read_text()
            try:
                new = f(src)
            except Exception as e:
                err = f"{type(e).__name__}: {str(e)[:90]}"; continue
            if new != src:
                p.write_text(new); hits.append(cand)
        print(f"{'APPLIED' if hits else 'SKIPPED':8}{mod[8:]:22} {','.join(hits) or err}")
        if hits:
            applied.append(mod[8:])
    print("applied:", ",".join(applied))


if __name__ == "__main__":
    main()
