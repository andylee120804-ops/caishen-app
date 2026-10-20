"""一次性抠图：把 4 张 Q版卡通铜器从米色背景抠成透明 PNG。
输入：props/Q_version_chibi_Chinese_cartoo_*.png
输出：props/ware_{lamp,vase,flower,basin}.png
"""
from pathlib import Path
from PIL import Image
from rembg import remove

BASE = Path(__file__).resolve().parent.parent / "entry/src/main/resources/rawfile/props"
FILES = {
    "ware_lamp":   "Q_version_chibi_Chinese_cartoo_2026-10-18T15-55-55.png",
    "ware_vase":   "Q_version_chibi_Chinese_cartoo_2026-10-18T15-56-03.png",
    "ware_flower": "Q_version_chibi_Chinese_cartoo_2026-10-18T15-56-05.png",
    "ware_basin":  "Q_version_chibi_Chinese_cartoo_2026-10-18T15-56-08.png",
}

for out, inp in FILES.items():
    src = BASE / inp
    dst = BASE / f"{out}.png"
    if not src.exists():
        print(f"[FAIL] missing {src}")
        continue
    print(f">> cut {inp} -> {dst.name}")
    img = Image.open(src).convert("RGBA")
    out_img = remove(img)
    out_img.save(dst, "PNG")
    print(f"[OK] {dst.name}  {dst.stat().st_size/1024:.1f} KB")
print("DONE")
