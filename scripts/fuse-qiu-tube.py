"""签筒融合脚本 - 去边缘奶油色光晕 + 生成落地投影/氛围光晕素材。

用户反馈：签筒与深色背景有明显割裂。逐像素定位到两个根因：
1) rembg 抠图后边缘残留原图「奶油底」反光（最亮 400 边缘像素均值 [234,222,199]），
   在 #1a1a0a 深底上形成浅色描边；
2) 签筒悬空，无落地投影；自带暖光与无光背景冲突。

处理：
- decontaminate()：把半透明边缘像素的 RGB 吸附到最近的不透明前景色（只改色、
  不动 alpha），去除奶油反光、保留软边形状；
- 覆盖 qiu_art.png（先备份到 _v2_qiu/orig/）；
- 生成 qiu_shadow.png（黑色柔边椭圆投影）与 qiu_glow.png（暖色径向光晕），
  供 QiuQian.ets 复刻木鱼页 «地面投影 + 光晕» 的融合手法。

用法：
    python scripts/fuse-qiu-tube.py
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import distance_transform_edt

BASE = Path(__file__).resolve().parent.parent / "entry/src/main/resources/rawfile/props"
SRC = BASE / "qiu_art.png"
BACKUP = BASE / "_v2_qiu" / "orig" / "qiu_art_v2_tubeA_fringed.png"
SHADOW_OUT = BASE / "qiu_shadow.png"
GLOW_OUT = BASE / "qiu_glow.png"

OPAQUE_ALPHA = 220          # alpha 达此值视为前景（颜色可信，不再参与吸附）
SHADOW_SIZE = 512           # 投影画布（与 muyu_shadow.png 一致）
SHADOW_RX = 150             # 投影椭圆半宽（px）
SHADOW_RY = 50              # 投影椭圆半高
SHADOW_BLUR = 24            # 高斯模糊半径（柔边）
SHADOW_MAX_ALPHA = 78       # 投影中心最大 alpha（muyu 为 74，取同级柔和度）
GLOW_SIZE = 640             # 光晕画布（方形径向）
GLOW_MAX_ALPHA = 96         # 光晕中心最大 alpha（0.38 感知，柔和）
GLOW_COLOR = (249, 168, 60)  # 暖琥珀金（app 主色 #f9ca24 偏暖一档，贴签筒红金调）


def decontaminate(im: Image.Image) -> Image.Image:
    """把半透明边缘像素的 RGB 吸附到最近的不透明前景色，去除抠图反光。"""
    arr = np.asarray(im).astype(np.int16)
    alpha = arr[:, :, 3]
    opaque = alpha >= OPAQUE_ALPHA
    semi = (alpha > 0) & ~opaque

    # 每个像素指向最近的不透明像素坐标（scipy EDT：input=非不透明为 1，
    # return_indices 给出最近 input==0 即最近不透明像素的坐标）
    mask = (~opaque).astype(np.uint8)
    _, idx = distance_transform_edt(mask, return_indices=True)
    nearest = arr[idx[0], idx[1], :3]  # (H, W, 3)

    out = arr.copy()
    out[semi, :3] = nearest[semi]
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGBA")


def make_shadow() -> Image.Image:
    """黑色柔边椭圆落地投影（复刻 muyu_shadow.png 的做法）。"""
    # 先在灰度图里画椭圆 → 高斯模糊 → 作为纯黑 RGBA 的 alpha 通道
    blur = Image.new("L", (SHADOW_SIZE, SHADOW_SIZE), 0)
    d = ImageDraw.Draw(blur)
    cx = cy = SHADOW_SIZE // 2
    d.ellipse((cx - SHADOW_RX, cy - SHADOW_RY, cx + SHADOW_RX, cy + SHADOW_RY),
              fill=int(SHADOW_MAX_ALPHA / 255 * 255))
    blur = blur.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    # 模糊会把中心峰值拉低，重新归一化到目标峰值，保证中心深度一致
    peak = blur.getextrema()[1]
    if peak > 0:
        scale = SHADOW_MAX_ALPHA / peak
        blur = blur.point(lambda v: int(min(255, v * scale)))
    return Image.merge("RGBA", (Image.new("L", blur.size, 0),
                                Image.new("L", blur.size, 0),
                                Image.new("L", blur.size, 0),
                                blur))


def make_glow() -> Image.Image:
    """暖色径向光晕：中心亮 → 边缘透明（幂次衰减，柔和过渡）。"""
    half = GLOW_SIZE // 2
    yy, xx = np.mgrid[0:GLOW_SIZE, 0:GLOW_SIZE].astype(np.float32)
    dx = (xx - half) / half
    dy = (yy - half) / half
    d = np.sqrt(dx * dx + dy * dy)
    # 1 - d^2.2：近中心接近 1、边缘平滑归 0；裁剪负值
    falloff = np.clip(1.0 - np.power(d, 2.2), 0.0, 1.0)
    alpha = (falloff * GLOW_MAX_ALPHA).astype(np.uint8)

    r = np.full((GLOW_SIZE, GLOW_SIZE), GLOW_COLOR[0], dtype=np.uint8)
    g = np.full((GLOW_SIZE, GLOW_SIZE), GLOW_COLOR[1], dtype=np.uint8)
    b = np.full((GLOW_SIZE, GLOW_SIZE), GLOW_COLOR[2], dtype=np.uint8)
    return Image.merge("RGBA", (Image.fromarray(r), Image.fromarray(g),
                                Image.fromarray(b), Image.fromarray(alpha)))


def main() -> None:
    BACKUP.parent.mkdir(parents=True, exist_ok=True)
    if not BACKUP.exists():
        Image.open(SRC).save(BACKUP)
        print(f"backup -> {BACKUP.name} ({BACKUP.stat().st_size / 1024:.0f} KB)")
    else:
        print(f"backup exists, skip: {BACKUP.name}")

    im = Image.open(SRC).convert("RGBA")
    fixed = decontaminate(im)

    # 校验：边缘半透明白色反光应显著减少
    arr = np.asarray(fixed).astype(np.int16)
    a = arr[:, :, 3]
    semi = (a > 0) & (a < 250)
    bright_before = _bright_edge_ratio(im)
    bright_after = _bright_edge_ratio(fixed)
    print(f"边缘亮像素占比 before={bright_before:.4f} after={bright_after:.4f} "
          f"(半透明边缘像素 {semi.sum()})")

    fixed.save(SRC, "PNG", optimize=True)
    print(f"saved {SRC.name} ({SRC.stat().st_size / 1024:.0f} KB)")

    shadow = make_shadow()
    shadow.save(SHADOW_OUT, "PNG", optimize=True)
    print(f"saved {SHADOW_OUT.name} ({shadow.size}, {SHADOW_OUT.stat().st_size / 1024:.0f} KB)")

    glow = make_glow()
    glow.save(GLOW_OUT, "PNG", optimize=True)
    print(f"saved {GLOW_OUT.name} ({glow.size}, {GLOW_OUT.stat().st_size / 1024:.0f} KB)")


def _bright_edge_ratio(im: Image.Image) -> float:
    arr = np.asarray(im).astype(np.int16)
    a = arr[:, :, 3]
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    semi = (a > 0) & (a < 250)
    if semi.sum() == 0:
        return 0.0
    bright = (r > 180) & (g > 160) & (b > 130) & ((r - b) < 60)
    return float((bright & semi).sum() / semi.sum())


if __name__ == "__main__":
    main()