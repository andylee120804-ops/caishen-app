# 木鱼多档候选 + 对比图：轮廓 alpha 与原图逐像素一致，仅按不同"精致度"参数渲染漆身/描金/光影。
# 输出 _v2_muyu/muyu_cand_{subtle,medium,bold}.png 与 muyu_compare.png（透明底棋盘格对比图）
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V2 = os.path.join(ROOT, 'entry/src/main/resources/rawfile/props/_v2_muyu')
SRC = os.path.join(V2, 'orig/muyu_v1.png')

_src = Image.open(SRC).convert('RGBA')
_arr = np.asarray(_src).astype(np.float32)
_alpha = _arr[:, :, 3].astype(np.uint8)
_rgb = _arr[:, :, :3]
H, W = _alpha.shape
_inmask = _alpha > 200
_solid = _alpha > 245
_lum = _rgb.mean(axis=2)
_carved = _inmask & (_lum > 150) & ((_rgb[:, :, 0] - _rgb[:, :, 2]) > 70)
_carved = ndimage.binary_opening(_carved, iterations=1)
_body = _inmask & ~_carved
_yy, _xx = np.mgrid[0:H, 0:W].astype(np.float32)
_dist = ndimage.distance_transform_edt(_solid)
_dmax = max(_dist.max(), 1)
_inner = np.clip(_dist, 0, None) / _dmax
_bump = np.sin(np.clip(_inner, 0, 1) * np.pi * 0.5) ** 0.6
_gy_top = _yy[_carved].min() if _carved.any() else 0
_gy_bot = _yy[_carved].max() if _carved.any() else H
_gt = np.clip((_yy - _gy_top) / max(_gy_bot - _gy_top, 1), 0, 1)
_edge_dist = ndimage.distance_transform_edt(_inmask)
_edge_near = _inmask & (_edge_dist < 2.5)
_edge_gold = _inmask & (_edge_dist < 5.0) & ~_edge_near
_carved_dil = ndimage.binary_dilation(_carved, iterations=2)
_under = _body & _carved_dil


def make(p):
    t = _yy / H
    top = np.array(p['lacquer_top'], np.float32)
    bot = np.array(p['lacquer_bot'], np.float32)
    base = top * (1 - t[..., None]) + bot * t[..., None]
    vol = p['base_vol'] + p['vol_gain'] * _bump
    body_col = base * vol[..., None]
    key = (((W - _xx) / W * 0.6 + (H - _yy) / H * 0.4) - 0.5) * p['key_gain']
    body_col += key[..., None]
    grain = (np.sin(_xx * 0.16 + np.sin(_yy * 0.03) * 2.2) * p['grain'] +
             np.sin(_yy * 0.55 + _xx * 0.01) * p['grain'] * 0.45)
    body_col[:, :, 0] += grain
    body_col[:, :, 1] += grain * 0.8
    body_col[:, :, 2] += grain * 0.5
    gx, gy = W * 0.42, H * 0.30
    spec = np.exp(-(((_xx - gx) / (W * 0.22)) ** 2 + ((_yy - gy) / (H * 0.13)) ** 2))
    gloss = (spec[..., None] * np.array(p['gloss'], np.float32)) * (_bump[..., None] > p['gloss_thr'])
    body_col += gloss
    gold_top = np.array(p['gold_top'], np.float32)
    gold_bot = np.array(p['gold_bot'], np.float32)
    gold_col = gold_top * (1 - _gt[..., None]) + gold_bot * _gt[..., None]
    gold_col += (_bump[..., None] - 0.55) * p['gold_bump']
    out = body_col.copy()
    out[_carved] = gold_col[_carved]
    out[_under] *= p['under_shadow']
    out[_edge_near] *= p['edge_dark']
    eg = np.array(p['edge_gold'], np.float32)
    out[_edge_gold] = out[_edge_gold] * (1 - p['edge_gold_mix']) + eg * p['edge_gold_mix']
    out = np.clip(out, 0, 255)
    l2 = out.mean(axis=2, keepdims=True)
    out = l2 + (out - l2) * p['sat']
    out[:, :, 0] += p['warm']
    out[:, :, 2] -= p['warm'] + 1
    out = np.clip(out, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([out, _alpha]), 'RGBA')


VARIANTS = {
    'subtle': dict(label='A 清透原味', lacquer_top=[176, 120, 86], lacquer_bot=[128, 80, 52],
                   base_vol=0.80, vol_gain=0.40, key_gain=34, grain=2.4, gloss=[46, 40, 32],
                   gloss_thr=0.7, gold_top=[248, 214, 140], gold_bot=[205, 150, 62], gold_bump=14,
                   under_shadow=0.86, edge_dark=0.68, edge_gold=[236, 200, 108], edge_gold_mix=0.55,
                   sat=1.06, warm=3),
    'medium': dict(label='B 精修(当前v3)', lacquer_top=[182, 96, 50], lacquer_bot=[116, 44, 24],
                   base_vol=0.70, vol_gain=0.55, key_gain=44, grain=3.2, gloss=[64, 54, 42],
                   gloss_thr=0.6, gold_top=[255, 236, 160], gold_bot=[198, 140, 44], gold_bump=22,
                   under_shadow=0.80, edge_dark=0.55, edge_gold=[242, 206, 110], edge_gold_mix=0.70,
                   sat=1.14, warm=5),
    'bold': dict(label='C 重漆描金', lacquer_top=[150, 74, 42], lacquer_bot=[84, 28, 16],
                 base_vol=0.62, vol_gain=0.66, key_gain=54, grain=3.6, gloss=[84, 70, 54],
                 gloss_thr=0.45, gold_top=[255, 242, 175], gold_bot=[176, 116, 28], gold_bump=30,
                 under_shadow=0.74, edge_dark=0.48, edge_gold=[246, 210, 116], edge_gold_mix=0.82,
                 sat=1.22, warm=6),
}

for k, p in VARIANTS.items():
    make(p).save(os.path.join(V2, f'muyu_cand_{k}.png'), optimize=True)
    print('made', k)


def load_font(sz):
    for fp in ['C:/Windows/Fonts/msyh.ttc', 'C:/Windows/Fonts/msyh.ttf', 'C:/Windows/Fonts/arial.ttf']:
        if os.path.exists(fp):
            try:
                return ImageFont.truetype(fp, sz)
            except Exception:
                pass
    return ImageFont.load_default()


CELL = 384
BAR = 40
PAD = 14
items = [('原版 Original', _src)] + [(p['label'], make(p)) for p in VARIANTS.values()]
cols = 2
rows = (len(items) + cols - 1) // cols
MW = cols * CELL + (cols + 1) * PAD
MH = rows * (CELL + BAR) + (rows + 1) * PAD
canvas = Image.new('RGB', (MW, MH), (24, 22, 16))
draw = ImageDraw.Draw(canvas)
# 棋盘格单元
ck = 16
c1, c2 = (58, 54, 46), (74, 70, 60)
for i, (label, img) in enumerate(items):
    r, c = divmod(i, cols)
    x0 = PAD + c * (CELL + PAD)
    y0 = PAD + r * (CELL + BAR + PAD)
    draw.rectangle([x0, y0, x0 + CELL, y0 + BAR], fill=(249, 202, 36))
    draw.text((x0 + 12, y0 + BAR // 2), label, fill=(26, 26, 10), font=load_font(20), anchor='lm')
    bx, by = x0, y0 + BAR
    for gy2 in range(by, by + CELL, ck):
        for gx2 in range(x0, x0 + CELL, ck):
            draw.rectangle([gx2, gy2, min(gx2 + ck, x0 + CELL), min(gy2 + ck, by + CELL)],
                           fill=c1 if ((gx2 // ck + gy2 // ck) % 2 == 0) else c2)
    thumb = img.resize((CELL - 24, CELL - 24), Image.LANCZOS)
    canvas.paste(thumb, (x0 + 12, by + 12), thumb)
out_path = os.path.join(V2, 'muyu_compare.png')
canvas.save(out_path, optimize=True)
print('montage', out_path, os.path.getsize(out_path) // 1024, 'KB', canvas.size)
