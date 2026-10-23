#!/usr/bin/env python3
"""Survey which openfpga-PlayStation area patches apply to the SYSTEM11_MiSTer RTL.

Each upstream patch exposes a pure text transform (`*_text`). We try every transform on every
candidate S11 source file and report the ones that apply (return changed text, no error).
Usage: ps_patch_survey.py [--write DIR]   (writes patched files as DIR/<patch>/<file>)
"""
import argparse, importlib, inspect, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
S11 = ROOT / "references/SYSTEM11_MiSTer/rtl"


def scratch_root():
    """Copy of the PS port's scripts/rtl plus a PSX_MiSTer link: the scripts read their pinned
    upstream at import time and expect it under <root>/references."""
    import shutil, subprocess
    root = ROOT / "build/ps_root"
    src = ROOT / "references/openfpga-PlayStation"
    rev = subprocess.run(["git", "-C", str(src), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    if root.exists() and (root / ".rev").exists() and (root / ".rev").read_text() != rev:
        shutil.rmtree(root)   # the submodule moved: copy its scripts again
    if not root.exists():
        root.mkdir(parents=True)
        (root / ".rev").write_text(rev)
        for d in ("scripts", "rtl", "support"):
            if (src / d).exists():
                shutil.copytree(src / d, root / d)
        (root / "references").mkdir()
        (root / "references/PSX_MiSTer").symlink_to(ROOT / "references/PSX_MiSTer")
    return root


sys.path.insert(0, str(scratch_root() / "scripts"))

PATCHES = {  # module -> text functions (single-arg `text` unless noted)
    "prepare_gpu_area_reg": ["area_reg_text"], "prepare_gpu_cache_controls": ["cache_controls_text"],
    "prepare_gpu_dy_ram": ["dy_ram_text"], "prepare_gpu_mul_narrow": ["mul_narrow_text"],
    "prepare_gpu_poly_onehot": ["onehot_text"], "prepare_gpu_no_watchdog": ["no_watchdog_text"],
    "prepare_gpu_sort_reread": ["sort_reread_text"], "prepare_gpu_half_pipe": ["half_pipe_text"],
    "prepare_gpu_read_late": ["read_late_text"], "prepare_gpu_vertex_ram": ["vertex_ram_text"],
    "prepare_gpu_mul_retime": ["mul_retime_text"], "prepare_gpu_poly_share": ["poly_share_text"],
    "prepare_gpu_tag_generation": ["tag_generation_text"],
    "prepare_gte_control_ram": ["control_ram_text", "data_ram_text"],
    "prepare_gte_multicycle": ["adapter_text"], "prepare_gte_matrix_ram": ["compute_path_text", "engine_text"],
    "prepare_gte_vector_ram": ["vector_ram_text"], "prepare_gte_add_table": ["add_table_text"],
    "prepare_gte_mac_ram": ["regs_text", "engine_text", "compute_text"],
    "prepare_dma_channel_ram": ["channel_ram_text"], "prepare_dma_chcr_ram": ["chcr_ram_text"],
    "prepare_mdec_mednafen": ["mednafen_text"], "prepare_mdec_idct_pipe": ["idct_pipe_text"],
    "prepare_cpu_execute_share": ["execute_share_text"], "prepare_cpu_regfile_ram": ["regfile_ram_text"],
}
CANDIDATES = sorted(p.name for p in S11.glob("*.vhd") if p.name.startswith(("gpu", "dma", "mdec", "cpu", "memorymux", "datacache")))


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--write")
    a = ap.parse_args()
    for mod, funcs in PATCHES.items():
        try:
            m = importlib.import_module(mod)
        except Exception as e:
            print(f"{mod:34} IMPORT FAIL {type(e).__name__}: {str(e)[:70]}"); continue
        for fn in funcs:
            f = getattr(m, fn, None)
            if f is None:
                print(f"{mod:34} {fn}: missing"); continue
            hits, last = [], ""
            for cand in CANDIDATES:
                src = (S11 / cand).read_text()
                try:
                    out = f(src)
                except Exception as e:
                    last = f"{type(e).__name__}: {str(e)[:80]}"; continue
                if out != src:
                    hits.append(cand)
                    if a.write:
                        d = Path(a.write) / f"{mod}.{fn}"; d.mkdir(parents=True, exist_ok=True)
                        (d / cand).write_text(out)
            status = ("APPLIES -> " + ",".join(hits)) if hits else "no match (" + last + ")"
            print(f"{mod:34} {fn:22} {status}")


if __name__ == "__main__":
    main()
