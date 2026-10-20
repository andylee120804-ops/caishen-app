# 木鱼精修 v3：轮廓/构图与原版逐像素一致（alpha 直接沿用原图），仅升级渲染质感：
#   深漆红棕渐变漆身 / 球面体积光影 / 方向性主光 / 木纹 / 漆面高光 /
#   雕刻金色纹样重绘为金属描金 / 内描暗线 + 金包边 / 纹样下陷投影 / 暖色分级
# 用法：python scripts/enhance-muyu-v3.py  -> 输出 muyu_enh3.png（与原图同 512x512）
import numpy as np
from PIL import Image
from scipy import ndimage
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'entry/src/main/resources/rawfile/props/_v2_muyu/orig/muyu_v1.png')
DST = os.path.join(ROOT, 'entry/src/main/resources/rawfile/props/_v2_muyu/muyu_enh3.png')

im = Image.open(SRC).convert('RGBA')
arr = np.asarray(im).astype(np.float32)
alpha = arr[:, :, 3].astype(np.uint8)          # 轮廓 alpha：直接沿用，保证外形逐像素不变
rgb = arr[:, :, :3]
H, W = alpha.shape

inmask = alpha > 200                           # 实体内部
solid = alpha > 245
lum = rgb.mean(axis=2)

# 原图金色雕刻纹样（嘴缝/鳞弧/圆点）：高亮度 + 暖金（R 明显高于 B）
carved = inmask & (lum > 150) & ((rgb[:, :, 0] - rgb[:, :, 2]) > 70)
carved = ndimage.binary_opening(carved, iterations=1)   # 去零散噪点
body = inmask & ~carved

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

# -- 1) 球面体积光影：内部距离场 -> 中部隆起、边缘转暗 --
dist = ndimage.distance_transform_edt(solid)
dmax = max(dist.max(), 1)
inner = np.clip(dist, 0, None) / dmax
bump = np.sin(np.clip(inner, 0, 1) * np.pi * 0.5) ** 0.6
vol = 0.70 + 0.55 * bump

# -- 2) 漆身：深红棕渐变 + 方向性主光（左上）+ 木纹 --
t = yy / H
top = np.array([182, 96, 50], np.float32)
bot = np.array([116, 44, 24], np.float32)
base = top * (1 - t[..., None]) + bot * t[..., None]
body_col = base * vol[..., None]
key = (((W - xx) / W * 0.6 + (H - yy) / H * 0.4) - 0.5) * 44.0
body_col += key[..., None]
grain = (np.sin(xx * 0.16 + np.sin(yy * 0.03) * 2.2) * 3.2 +
         np.sin(yy * 0.55 + xx * 0.01) * 1.4)
body_col[:, :, 0] += grain
body_col[:, :, 1] += grain * 0.8
body_col[:, :, 2] += grain * 0.5

# 漆面柔和高光（上中部椭圆，只在隆起受光处叠加）
gx, gy = W * 0.42, H * 0.30
spec = np.exp(-(((xx - gx) / (W * 0.22)) ** 2 + ((yy - gy) / (H * 0.13)) ** 2))
body_col += (spec[..., None] * np.array([64, 54, 42], np.float32)) * (bump[..., None] > 0.6)

# -- 3) 金属描金：雕刻纹样 -> 竖向两段金属渐变（亮金->深金） --
gy_top = yy[carved].min() if carved.any() else 0
gy_bot = yy[carved].max() if carved.any() else H
gt = np.clip((yy - gy_top) / max(gy_bot - gy_top, 1), 0, 1)
gold_top = np.array([255, 236, 160], np.float32)
gold_bot = np.array([198, 140, 44], np.float32)
gold_col = gold_top * (1 - gt[..., None]) + gold_bot * gt[..., None]
gold_col += (bump[..., None] - 0.55) * 22.0

# -- 4) 合成漆身 + 描金 --
out = body_col.copy()
out[carved] = gold_col[carved]

# -- 5) 纹样下陷投影：描金紧邻的漆身压暗，营造嵌进去的雕刻感 --
carved_dil = ndimage.binary_dilation(carved, iterations=2)
under = body & carved_dil
out[under] *= 0.80

# -- 6) 边缘：1~2px 内描暗线（雕刻收边）+ 2px 亮金包边（工艺描金）--
edge_dist = ndimage.distance_transform_edt(inmask)
edge_near = inmask & (edge_dist < 2.5)
edge_gold = inmask & (edge_dist < 5.0) & ~edge_near
out[edge_near] *= 0.55
out[edge_gold] = out[edge_gold] * 0.30 + np.array([242, 206, 110], np.float32) * 0.70

# -- 7) 暖色分级（饱和微增 + 提红压蓝）--
out = np.clip(out, 0, 255)
l2 = out.mean(axis=2, keepdims=True)
out = l2 + (out - l2) * 1.14
out[:, :, 0] += 5
out[:, :, 2] -= 6
out = np.clip(out, 0, 255).astype(np.uint8)

# 合成：沿用原图 alpha（外形不变），仅 RGB 升级
res = np.dstack([out, alpha])
Image.fromarray(res, 'RGBA').save(DST, optimize=True)
print('saved', DST, os.path.getsize(DST) // 1024, 'KB  carved_px=', int(carved.sum()))
