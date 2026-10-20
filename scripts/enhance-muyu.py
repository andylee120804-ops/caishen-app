# 木鱼细节化精修 v2：以原始素材为底（轮廓 alpha 逐像素不变），重绘质感：
# 高反差锐化雕纹 / 球面光影 / 金属描金重绘 / 内描线+金包边 / 漆面颗粒 / 色彩分级
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = 'entry/src/main/resources/rawfile/props/_v2_muyu/orig/muyu_v1.png'
DST = 'entry/src/main/resources/rawfile/props/_v2_muyu/muyu_enh.png'

im = Image.open(SRC).convert('RGBA').resize((1024, 1024), Image.LANCZOS)
arr = np.asarray(im).astype(np.int16)
alpha = arr[:, :, 3].astype(np.uint8)
rgb = arr[:, :, :3].astype(np.float32)
H, W = alpha.shape
mask = alpha > 30
inmask = alpha > 200

# ── 1) USM 锐化：强化雕刻线条（鱼鳞/嘴/眼） ──
lum = rgb.mean(axis=2)
blur = ndimage.gaussian_filter(lum, sigma=2.2)
detail = lum - blur
sharp = rgb + np.expand_dims(detail * 1.15, -1)

# ── 2) 球面立体光影：内部距离场 → 中部隆起亮、边缘转暗 ──
dt = ndimage.distance_transform_edt(inmask)
dtmax = max(dt.max(), 1)
inner = np.clip(dt, 0, None) / dtmax
bump = np.sin(np.clip(inner, 0, 1) * np.pi * 0.5) ** 0.65
shade = (bump - 0.55) * 46.0                       # ±20 左右
rim = (dt < 10).astype(np.float32)
shade -= rim * 22.0                                # 边缘收暗
# 左上主光源方向性
yy, xx = np.mgrid[0:H, 0:W]
key = ((W - xx) / W * 0.6 + (H - yy) / H * 0.4 - 0.55) * 34.0
shade += key

# ── 3) 描金金属重绘：金色区 → 纵向两段金属渐变 + 保留原纹理高光 ──
gold = (rgb[:, :, 0] > 110) & (rgb[:, :, 0] - rgb[:, :, 2] > 42) & (rgb[:, :, 1] > rgb[:, :, 2]) & inmask
gmin, gmax = (yy[gold].min(), yy[gold].max()) if gold.any() else (0, H)
gt = np.clip((yy - gmin) / max(gmax - gmin, 1), 0, 1)
new_gold = np.stack([
    252 - gt * 52,      # R
    222 - gt * 62,      # G
    92 + gt * 40,       # B
], axis=-1)
blend = 0.85
sharp[gold] = sharp[gold] * (1 - blend) + new_gold[gold] * blend

# ── 4) 边缘：1px 内描暗线 + 2px 亮金包边 ──
imin = ndimage.minimum_filter(alpha, size=5)
edge_near = inmask & (imin < 96)
edge_gold = inmask & (imin < 220) & ~edge_near
sharp[edge_near] *= 0.62                            # 内描暗线（雕刻感）
sharp[edge_gold] = sharp[edge_gold] * 0.30 + np.array([240, 202, 104], dtype=np.float32) * 0.70

# ── 5) 木纹微纹理（不覆盖金色重绘区） ──
grain = np.sin(yy / 11.0 + xx * 0.004) * 4.0 + np.sin(yy / 3.7) * 1.8
non_gold = inmask & ~gold
sharp[:, :, 0][non_gold] += grain[non_gold]
sharp[:, :, 1][non_gold] += grain[non_gold] * 0.8
sharp[:, :, 2][non_gold] += grain[non_gold] * 0.5

# ── 6) 漆面颗粒 + 色彩分级（暖饱和微增） ──
rng = np.random.default_rng(11)
sharp += rng.normal(0, 1.6, (H, W, 1)) * np.expand_dims(inmask, -1)
sharp += (sharp - 128) * 0.05                          # 对比
sharp[:, :, 0][inmask] += 5                            # 提红
sharp[:, :, 2][inmask] -= 4                            # 压蓝
sharp += np.expand_dims(shade, -1)

out = np.clip(sharp, 0, 255).astype(np.uint8)
res = np.dstack([out, alpha])
Image.fromarray(res, 'RGBA').save(DST, optimize=True)

import os
print('saved', DST, os.path.getsize(DST) // 1024, 'KB')