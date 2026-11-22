"""磕头小人高清化 · 第 3 步：rembg 抠透明 + 全序列统一 bbox 裁剪放大 + 对比预览。
scripts/kowtow-hd-out/fXX.png -> scripts/kowtow-hd-final/kowtow_XX.png

统一 bbox：所有帧共用同一裁剪矩形 + 同一缩放系数（水平居中、底边对齐），
保证帧间人物位置/地面线对齐，动画不抖动。人物像财神像一样充满画幅。
--pilot 模式只处理已存在的输出帧（bbox 为试点帧的并集，仅供参考预览）。
"""
import sys
from pathlib import Path
from rembg import remove
from PIL import Image

SRC = Path("scripts/kowtow-hd-out")
FINAL = Path("scripts/kowtow-hd-final")
PREVIEW = Path("scripts/kowtow-hd-preview.html")
FINAL.mkdir(parents=True, exist_ok=True)
TARGET = 512          # 输出画布（显示端 240，512 足够）
MARGIN = 14           # 底边留白
PILOT = "--pilot" in sys.argv

cutouts = {}
for p in sorted(SRC.glob("f*.png")):
    out = FINAL / f"kowtow_{p.stem[1:]}.png"
    cut = remove(p.read_bytes())
    img = Image.open(__import__("io").BytesIO(cut)).convert("RGBA")
    img.save(out)
    cutouts[p.stem] = (out, img.getbbox())
    print(f"  rembg {p.name} -> {out.name} bbox={img.getbbox()}")

if not cutouts:
    print("no frames"); sys.exit(1)

# 全帧并集 bbox（同一坐标系：源帧均为 1024x1024 铺底后同构图）
x0 = min(b[0] for _, b in cutouts.values()); y0 = min(b[1] for _, b in cutouts.values())
x1 = max(b[2] for _, b in cutouts.values()); y1 = max(b[3] for _, b in cutouts.values())
union_w, union_h = x1 - x0, y1 - y0
scale = (TARGET - 2 * MARGIN) / max(union_w, union_h)
print(f"union bbox=({x0},{y0},{x1},{y1}) {union_w}x{union_h} scale={scale:.3f}")

for stem, (out, _) in cutouts.items():
    img = Image.open(out)
    crop = img.crop((x0, y0, x1, y1))
    nw, nh = round(union_w * scale), round(union_h * scale)
    crop = crop.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (TARGET, TARGET), (0, 0, 0, 0))
    canvas.alpha_composite(crop, ((TARGET - nw) // 2, TARGET - MARGIN - nh))
    canvas.save(out)
    print(f"  fit {out.name}")

# 对比预览 HTML：旧帧 vs 新帧（点大图肉眼比），附一张财神像作风格基准
raw = Path("entry/src/main/resources/rawfile/animations")
rows = ""
for stem in sorted(cutouts, key=lambda s: int(s[1:])):
    n = stem[1:]
    rows += f"""
    <div class="row"><div class="label">帧 {n}</div>
      <img src="{raw / f'kowtow_{n}.png'}"><img src="{FINAL / f'kowtow_{n}.png'}">
    </div>"""
PREVIEW.write_text(f"""<!DOCTYPE html><html><head><meta charset="utf-8">
<style>body{{font-family:sans-serif;background:#2b2016;color:#eee;padding:20px}}
h1{{font-size:18px}} .row{{margin:14px 0}} .label{{margin-bottom:4px;color:#ffd700}}
img{{width:280px;height:280px;background:#f3edde;border-radius:8px;margin-right:12px}}
.head{{color:#9ad}} .ref{{display:flex;align-items:center;gap:12px;margin:10px 0}}
.ref img{{background:#f3edde}}</style></head><body>
<h1>磕头小人高清化试点：左=当前线上帧，右=财神像风格重绘帧</h1>
<div class="ref head"><img src="entry/src/main/resources/rawfile/deities/2.png" style="width:160px;height:160px">
  <span>↑ 财神像风格基准（目标质感）</span></div>
{rows}</body></html>""", encoding="utf-8")
print(f"preview -> {PREVIEW}")
