"""磕头小人高清化 v2 · 几何对齐：完全继承原序列的帧间几何，零抖动、恢复原人物大小。

对每帧：
  1. rembg 抠出 HD 重绘帧的透明人物
  2. 以 scripts/kowtow-hd-backup 里原序列同名帧的 alpha bbox 为几何基准：
     - 等比缩放使人物高度 = 源帧人物高度（恢复原始视觉大小）
     - 底边对齐源帧 bbox 底边（地面线一致 → 垂直零抖动）
     - 水平中心对齐源帧 bbox 中心（横向零抖动）
  3. 输出 960x960 透明 PNG（与原序列同规格）

scripts/kowtow-hd-out2/fXX.png -> scripts/kowtow-hd-final2/kowtow_XX.png + 对比预览
"""
import sys
from pathlib import Path
from io import BytesIO
from rembg import remove
from PIL import Image

SRC = Path("scripts/kowtow-hd-out")       # v1 逐帧风格化输出（背面视角/构图跟随源帧）
GEOM = Path("scripts/kowtow-hd-backup")   # 原始 960x960 透明帧（几何基准）
FINAL = Path("scripts/kowtow-hd-final2")
PREVIEW = Path("scripts/kowtow-hd-preview2.html")
FINAL.mkdir(parents=True, exist_ok=True)
CANVAS = 960

def abbox(img: Image.Image):
    return img.getbbox()

report = []
for src in sorted(SRC.glob("f*.png")):
    idx = src.stem[1:]
    geom_path = GEOM / f"kowtow_{idx}.png"
    if not geom_path.exists():
        print(f"  MISS geom {idx}"); continue

    geo = Image.open(geom_path).convert("RGBA")
    sb = abbox(geo)                       # 源帧人物 bbox（960 坐标系）

    cut = remove(src.read_bytes())
    hd = Image.open(BytesIO(cut)).convert("RGBA")
    hb = abbox(hd)                        # HD 帧人物 bbox
    if not hb:
        print(f"  EMPTY rembg {idx}"); continue

    crop = hd.crop(hb)
    target_h = sb[3] - sb[1]
    scale = target_h / (hb[3] - hb[1])
    nw = max(1, round(crop.width * scale))
    crop = crop.resize((nw, target_h), Image.LANCZOS)

    cx = (sb[0] + sb[2]) / 2
    px = round(cx - nw / 2)
    py = sb[3] - target_h                 # 底边对齐
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(crop, (px, py))

    out = FINAL / f"kowtow_{idx}.png"
    canvas.save(out)
    report.append((idx, hb[3] - hb[1], target_h))
    print(f"  {idx}: hd_h={hb[3]-hb[1]} -> {target_h}px  pos=({px},{py})")

# 对比预览：旧序列动画 vs 新序列动画（JS 轮播 10fps），直接看抖动
frames = sorted(p.name for p in FINAL.glob("kowtow_*.png"))
old_frames = sorted(p.name for p in GEOM.glob("kowtow_*.png"))
def js_arr(names, base): return ",".join(f'"{base}/{n}"' for n in names)
PREVIEW.write_text(f"""<!DOCTYPE html><html><head><meta charset="utf-8"><style>
body{{font-family:sans-serif;background:#2b2016;color:#eee;padding:20px;text-align:center}}
img{{width:280px;height:280px;background:#f3edde;border-radius:8px;margin:6px}}
h1{{font-size:18px}} .fps{{color:#ffd700;margin-bottom:8px}}</style></head><body>
<h1>左=旧序列（几何基准），右=新高清序列（逐帧对齐后）</h1>
<div class="fps" id="f"></div>
<img id="a"><img id="b">
<script>
const A=[{js_arr(old_frames,'scripts/kowtow-hd-backup')}],B=[{js_arr(frames,'scripts/kowtow-hd-final2')}];
let i=0;const N=Math.max(A.length,B.length);
setInterval(()=>{{document.getElementById('a').src=A[i%A.length];
document.getElementById('b').src=B[i%B.length];
document.getElementById('f').textContent='帧 '+(i%N+1)+' / '+N+' (10fps)';i++;}},100);
</script></body></html>""", encoding="utf-8")
print(f"preview -> {PREVIEW}")
