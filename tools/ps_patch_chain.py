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
ORDER = [
    ("prepare_dma_channel_ram", "channel_ram_text"), ("prepare_dma_chcr_ram", "chcr_ram_text"),
    ("prepare_gpu_area_reg", "area_reg_text"), ("prepare_gpu_dy_ram", "dy_ram_text"),
    ("prepare_gpu_poly_share", "poly_share_text"), ("prepare_gpu_vertex_ram", "vertex_ram_text"),
    ("prepare_gpu_mul_narrow", "mul_narrow_text"), ("prepare_gpu_mul_retime", "mul_retime_text"),
    ("prepare_gpu_half_pipe", "half_pipe_text"), ("prepare_gpu_poly_onehot", "onehot_text"),
    ("prepare_gpu_no_watchdog", "no_watchdog_text"), ("prepare_gpu_tag_generation", "tag_generation_text"),
    ("prepare_gpu_sort_reread", "sort_reread_text"), ("prepare_gpu_read_late", "read_late_text"),
    ("prepare_gpu_cache_controls", "cache_controls_text"),
    ("prepare_mdec_mednafen", "mednafen_text"), ("prepare_mdec_idct_pipe", "idct_pipe_text"),
]


def main():
    out = Path(sys.argv[1]); only = set(sys.argv[2:])
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(sv.S11, out)
    applied = []
    for mod, fn in ORDER:
        if only and mod.replace("prepare_", "") not in only:
            continue
        f = getattr(importlib.import_module(mod), fn)
        hits, err = [], ""
        for cand in sv.CANDIDATES:
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
