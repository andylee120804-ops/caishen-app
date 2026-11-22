"""磕头关键帧自动择优：不靠肉眼，用三个数值指标从候选里挑最佳帧。

指标（rembg 后的 alpha 蒙版 + RGB）：
  1. 左右对称度（背面视角判据）：alpha 蒙版水平翻转后与原图的 IoU。
     纯背面 ≈ 对称（>0.75）；侧脸/3-4 视角明显不对称（<0.65）。
  2. 宽高比 w/h：须落在该姿态的期望区间（对齐源帧比例，放宽 ±）。
     kf2 中拜 0.55-0.95 / kf3 深拜 0.70-1.10 / kf4 伏地 0.85-1.60。
  3. 红袍占比：红色像素占比 > 0.10，确保画的是我们的小人。

输出：scripts/kowtow-kf/picked/kf{1..4}.png（kf1 直接用底图）+ 各候选评分表。
"""
import json
from pathlib import Path
from io import BytesIO
import numpy as np
from rembg import remove
from PIL import Image

CAND = Path("scripts/kowtow-kf/cand")
PICKED = Path("scripts/kowtow-kf/picked")
PICKED.mkdir(parents=True, exist_ok=True)

# 期望宽高比区间（参考源帧比例放宽；第二轮候选 HD 手办头身比更大，区间再放宽）
RANGES = {2: (0.55, 0.95), 3: (0.65, 1.15), 4: (0.78, 1.60)}
SYM_MIN = {2: 0.78, 3: 0.72, 4: 0.68}   # 伏地俯视允许手臂略不对称

def analyze(path: Path):
    im = Image.open(path).convert("RGBA")
    buf = BytesIO(); im.save(buf, "PNG")
    cut = Image.open(BytesIO(remove(buf.getvalue()))).convert("RGBA")
    bbox = cut.getbbox()
    if not bbox:
        return None
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    crop = cut.crop(bbox)

    # 对称度：alpha 蒙版归一 128x128，与水平翻转的 IoU
    m = crop.split()[3].resize((128, 128))
    a = (np.array(m) > 128)
    iou = (a & a[:, ::-1]).sum() / max(1, (a | a[:, ::-1]).sum())

    # 红袍占比（RGB 中红色主导像素 / 总不透明像素）
    rgb = np.array(crop.convert("RGB"), dtype=int)
    alpha = np.array(crop.split()[3]) > 128
    red = ((rgb[..., 0] > 120) & (rgb[..., 0] > rgb[..., 1] * 1.4) & (rgb[..., 0] > rgb[..., 2] * 1.4))
    red_frac = red[alpha].mean() if alpha.any() else 0.0

    return {"w": w, "h": h, "ratio": w / h, "sym": round(float(iou), 3),
            "red": round(float(red_frac), 3), "crop": crop}

results = {}
for kf in (2, 3, 4):
    rows = []
    for p in sorted(CAND.glob(f"kf{kf}_*.png")):
        n = p.stem.split("_", 1)[1]
        r = analyze(p)
        if r is None:
            rows.append({"cand": n, "err": "empty rembg"}); continue
        lo, hi = RANGES[kf]
        ratio_ok = lo <= r["ratio"] <= hi
        sym_ok = r["sym"] >= SYM_MIN[kf]
        red_ok = r["red"] >= 0.10
        r.update({"cand": n, "ratio_ok": ratio_ok, "sym_ok": sym_ok, "red_ok": red_ok,
                  "pass": ratio_ok and sym_ok and red_ok})
        rows.append(r)
    results[kf] = rows
    for r in rows:
        print(f"  kf{kf}_{r.get('cand')}: ratio={r.get('ratio')} sym={r.get('sym')} red={r.get('red')} pass={r.get('pass')}{(' err=' + r['err']) if 'err' in r else ''}")

# 择优：先取 pass 的，按 |ratio-区间中点| 最小；无 pass 则取 sym 最高者并告警
chosen = {}
for kf in (2, 3, 4):
    ok_rows = [r for r in results[kf] if r.get("pass")]
    pool = ok_rows or [r for r in results[kf] if "ratio" in r]
    if not pool:
        print(f"!! kf{kf} 无可用候选"); continue
    lo, hi = RANGES[kf]
    mid = (lo + hi) / 2
    best = min(pool, key=lambda r: (0 if r.get("pass") else 1, abs(r["ratio"] - mid) - r["sym"] * 0.1))
    crop = best.pop("crop")
    out = PICKED / f"kf{kf}.png"
    canvas = Image.new("RGBA", crop.size, (0, 0, 0, 0))
    canvas.alpha_composite(crop)
    canvas.save(out)
    chosen[kf] = {**best, "file": str(out), "forced": not ok_rows}
    print(f"  -> kf{kf} 选 cand{best['cand']} (forced={not ok_rows})")

(PICKED / "report.json").write_text(json.dumps(results, ensure_ascii=False, indent=1, default=str), encoding="utf-8")
print("picked:", json.dumps({k: v["cand"] for k, v in chosen.items()}))
