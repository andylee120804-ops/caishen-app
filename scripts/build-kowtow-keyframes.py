"""磕头关键帧资产构建：把择优选出的 4 帧统一到源序列几何，输出到 rawfile。

几何基准 = 源序列代表帧（scripts/kowtow-hd-backup）的 alpha bbox：
  kf1<-kowtow_01(站立) kf2<-kowtow_15(中拜) kf3<-kowtow_25(深拜) kf4<-kowtow_35(伏地)
每帧：rembg -> 裁 bbox -> 等比缩放到源帧人物高度 -> 底边对齐源帧地面线 + 水平中心对齐。
交叉淡入淡出时人物高度/位置随源动画连续变化，视觉上即"拜下去"。

输出: entry/src/main/resources/rawfile/animations/kowtow_kf1..4.png (960x960 透明)
"""
from pathlib import Path
from io import BytesIO
from rembg import remove
from PIL import Image

GEOM = Path("scripts/kowtow-hd-backup")
PICKED = Path("scripts/kowtow-kf/picked")
RAW = Path("entry/src/main/resources/rawfile/animations")

# 关键帧 <- 源几何基准帧
GEOM_SRC = {1: "kowtow_01.png", 2: "kowtow_15.png", 3: "kowtow_25.png", 4: "kowtow_35.png"}
# kf1 用已验证的 HD 站立帧（与源帧逐像素对齐过），kf2-4 用择优候选
# kf1 用已 rembg+对齐过的 HD 站立帧（kowtow-hd-final2，勿用带奶油底的 f01 原始输出）
HD_SRC = {1: Path("scripts/kowtow-hd-final2/kowtow_01.png")}

CANVAS = 960
for kf in (1, 2, 3, 4):
    g = Image.open(GEOM / GEOM_SRC[kf]).convert("RGBA")
    sb = g.getbbox()
    target_h = sb[3] - sb[1]
    cx = (sb[0] + sb[2]) / 2
    ground = sb[3]

    src = HD_SRC.get(kf, PICKED / f"kf{kf}.png")
    im = Image.open(src).convert("RGBA")
    if kf != 1:  # 候选需 rembg；kf1 源已是透明 HD
        buf = BytesIO(); im.save(buf, "PNG")
        im = Image.open(BytesIO(remove(buf.getvalue()))).convert("RGBA")
    hb = im.getbbox()
    crop = im.crop(hb)
    scale = target_h / (hb[3] - hb[1])
    nw = max(1, round(crop.width * scale))
    crop = crop.resize((nw, target_h), Image.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(crop, (round(cx - nw / 2), ground - target_h))
    out = RAW / f"kowtow_kf{kf}.png"
    canvas.save(out)
    print(f"  kf{kf}: h={target_h} ground={ground} cx={cx:.0f} w={nw} -> {out.name}")
print("done")
