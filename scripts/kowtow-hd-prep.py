"""磕头小人高清化 · 第 1 步：透明帧铺奶油底，供 Qwen-Image-Edit 使用。
rawfile/animations/kowtow_XX.png (960x960 透明) -> scripts/kowtow-hd-src/fXX.png (1024x1024 奶油底)
"""
from PIL import Image
from pathlib import Path

SRC = Path("entry/src/main/resources/rawfile/animations")
OUT = Path("scripts/kowtow-hd-src")
OUT.mkdir(parents=True, exist_ok=True)
CREAM = (243, 237, 222, 255)  # 与财神像 v2 的 light cream 背景一致

frames = sorted(SRC.glob("kowtow_*.png"))
for p in frames:
    img = Image.open(p).convert("RGBA")
    canvas = Image.new("RGBA", (1024, 1024), CREAM)
    canvas.alpha_composite(img, ((1024 - img.width) // 2, (1024 - img.height) // 2))
    out = OUT / f"f{p.stem.split('_')[1]}.png"
    canvas.convert("RGB").save(out)
    print(f"  {p.name} -> {out.name}")
print(f"prep done: {len(frames)} frames")
