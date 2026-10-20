# 木鱼实物化 3D 重绘（精细化版）：保持原轮廓 alpha 逐像素不变，1024 内部分辨率计算后缩回 512。
#   高度图(穹顶+倒角+凹槽) -> 法线 -> 漫反射/清漆高光/锐高光/补光/环境光遮蔽/菲涅尔边光
#   + 多层木纹 + 描金(金边/金线) + 凹槽倒角亮暗边。输出候选 + 棋盘格对比图，供挑选。
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V2 = os.path.join(ROOT, 'entry/src/main/resources/rawfile/props/_v2_muyu')
SRC = os.path.join(V2, 'orig/muyu_v1.png')
S = 1024

_src = Image.open(SRC).convert('RGBA')
_alpha512 = np.asarray(_src)[:, :, 3].astype(np.uint8)          # 最终输出 alpha：原图逐字节一致
_up = _src.resize((S, S), Image.LANCZOS)
arr = np.asarray(_up).astype(np.float32)
alpha = arr[:, :, 3].astype(np.uint8)
rgb = arr[:, :, :3]
H, W = alpha.shape

inmask = alpha > 200
solid = alpha > 245
lum = rgb.mean(axis=2)
carved = inmask & (lum > 150) & ((rgb[:, :, 0] - rgb[:, :, 2]) > 70)
carved = ndimage.binary_closing(ndimage.binary_opening(carved, iterations=1), iterations=2)
lab, n = ndimage.label(carved)
if n:
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    slit = np.zeros_like(carved)
    for i, s in enumerate(sizes, start=1):
        if s >= 0.10 * carved.sum():
            slit |= (lab == i)
else:
    slit = np.zeros_like(carved)
scales = carved & ~slit
carved_er = ndimage.binary_erosion(carved, iterations=3)
gold_ring = carved & ~carved_er                       # 雕刻边界金描边
slit_er = ndimage.binary_erosion(slit, iterations=4)
slit_thin = slit & ~slit_er                           # 嘴缝中缝金线
gold_paint = gold_ring | slit_thin

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)


def fbm(shape, octaves, seed, freq=4.0):
    out = np.zeros(shape, np.float32); amp = 1.0; tot = 0.0
    for o in range(octaves):
        r = np.random.default_rng(seed + o).random(shape).astype(np.float32)
        r = ndimage.gaussian_filter(r, sigma=shape[0] / (freq * 2.2 ** o))
        out += r * amp; tot += amp; amp *= 0.5
    return out / tot


# 高度图
edge_dist = ndimage.distance_transform_edt(inmask)
edmax = max(edge_dist.max(), 1)
dome = np.clip(edge_dist / (0.62 * edmax), 0, 1)
dome = np.sin(dome * np.pi / 2) ** 0.85
bevel = np.clip(edge_dist / 30.0, 0, 1) ** 0.7
h = dome * bevel
h[slit] -= 0.38
h[scales] -= 0.18
h = ndimage.gaussian_filter(h, sigma=5.0)
h = (h - h.min()) / (h.max() - h.min() + 1e-6)

gy, gx = np.gradient(h)
strength = 46.0
N = np.stack([-gx * strength, -gy * strength, np.ones_like(h)], -1)
N /= (np.linalg.norm(N, axis=2, keepdims=True) + 1e-6)


def norm3(v):
    v = np.array(v, np.float32); return v / (np.linalg.norm(v) + 1e-6)


def render(p):
    # 多层木纹（沿长轴横向纤维）
    nse = fbm((H, W), 5, 5, freq=4.0)
    nse2 = fbm((H, W), 4, 12, freq=1.4)
    grain = (np.sin(yy * 0.95 + nse * 8.0) * 0.55 +
             np.sin(yy * 0.42 + nse * 4.0 + nse2 * 2.0) * 0.35 +
             np.sin(yy * 0.18 + nse * 2.0) * 0.20)
    top = np.array(p['top'], np.float32); bot = np.array(p['bot'], np.float32)
    t = (yy / H * 0.62 + h * 0.38)
    albedo = top[None, None, :] * (1 - t[..., None]) + bot[None, None, :] * t[..., None]
    albedo = albedo * (1.0 + grain[..., None] * p['grain_amp'])
    albedo[carved] *= 0.80                                   # 凹槽吃漆/暗
    if p.get('gold'):
        gtop = np.array(p['gold_top'], np.float32); gbot = np.array(p['gold_bot'], np.float32)
        gt = np.clip((yy - yy[gold_paint].min()) / max(yy[gold_paint].max() - yy[gold_paint].min(), 1), 0, 1)
        gold_col = gtop[None, None, :] * (1 - gt[..., None]) + gbot[None, None, :] * gt[..., None]
        albedo[gold_paint] = gold_col[gold_paint]

    L1 = norm3([-0.55, -0.68, 0.46])                         # 主光 左上
    L2 = norm3([0.62, 0.42, 0.55])                           # 补光 右下
    V = norm3([0, 0, 1])
    d1 = np.clip((N * L1).sum(2), 0, 1)
    d2 = np.clip((N * L2).sum(2), 0, 1)
    Hv = norm3(L1 + V)
    sharp = np.clip((N * Hv).sum(2), 0, 1) ** p['shiny'] * p['spec']
    Hc = norm3(L1 * 0.7 + V)                                 # 清漆层（宽柔）
    clear = np.clip((N * Hc).sum(2), 0, 1) ** 16 * 0.18
    fres = np.clip(1.0 - N[:, :, 2], 0, 1) ** 3 * 0.5        # 菲涅尔边光

    ao = np.clip(0.42 + 0.58 * h, 0, 1) ** 1.25
    amb = p['ambient']
    key = np.array(p['key'], np.float32); fill = np.array(p['fill'], np.float32)
    color = albedo * (amb * ao[..., None] + d1[..., None] * key[None, None, :] +
                      d2[..., None] * fill[None, None, :] * 0.6)
    spc = np.array(p['spec_color'], np.float32)
    color = color + (sharp[..., None] * 255.0) * spc[None, None, :] * ao[..., None]
    color = color + (clear[..., None] * 255.0) * np.array(p['clear_color'], np.float32)[None, None, :] * ao[..., None]
    rim = np.array(p['rim_color'], np.float32)
    color = color + (fres[..., None] * 255.0 * 0.35) * rim[None, None, :] * inmask[..., None]
    if p.get('gold'):
        gs = np.clip((N * Hv).sum(2), 0, 1) ** 40 * 0.9
        color = color + (gs[..., None] * 255.0) * np.array([1.0, 0.95, 0.8], np.float32)[None, None, :] * gold_paint[..., None]

    # 接地接触阴影
    contact = np.clip((yy - (H * 0.80)) / (H * 0.12), 0, 1)
    color *= (1.0 - 0.16 * contact[..., None] * inmask[..., None])

    color = np.clip(color, 0, 255)
    l2 = color.mean(2, keepdims=True)
    color = l2 + (color - l2) * p['sat']
    color[:, :, 0] += p['warm']; color[:, :, 2] -= p['warm'] + 2
    color = np.clip(color, 0, 255).astype(np.uint8)

    # 缩回 512 + 还原原版 alpha
    rgb512 = Image.fromarray(color, 'RGB').resize((512, 512), Image.LANCZOS)
    return np.dstack([np.asarray(rgb512), _alpha512])


PRESETS = {
    'lacquer': dict(label='1 红漆描金(亮漆·精修)', top=[208, 110, 60], bot=[86, 30, 17],
                    grain_amp=0.06, shiny=110, spec=0.62, spec_color=[1.0, 0.96, 0.84],
                    clear_color=[1.0, 0.92, 0.80], rim_color=[1.0, 0.85, 0.7],
                    ambient=0.40, key=[1.0, 0.90, 0.76], fill=[0.30, 0.36, 0.52],
                    sat=1.18, warm=6, gold=True, gold_top=[255, 240, 168], gold_bot=[196, 138, 44]),
    'rosewood': dict(label='2 紫檀木(哑光)', top=[124, 64, 46], bot=[52, 24, 17],
                     grain_amp=0.10, shiny=16, spec=0.16, spec_color=[0.85, 0.72, 0.62],
                     clear_color=[0.8, 0.7, 0.6], rim_color=[0.7, 0.6, 0.55],
                     ambient=0.48, key=[1.0, 0.88, 0.74], fill=[0.28, 0.33, 0.48],
                     sat=1.10, warm=4, gold=False),
    'sandal': dict(label='3 原木做旧(暖棕)', top=[178, 130, 86], bot=[104, 64, 38],
                   grain_amp=0.13, shiny=22, spec=0.20, spec_color=[0.92, 0.80, 0.66],
                   clear_color=[0.85, 0.74, 0.62], rim_color=[0.8, 0.68, 0.56],
                   ambient=0.52, key=[1.0, 0.92, 0.78], fill=[0.30, 0.34, 0.46],
                   sat=1.06, warm=3, gold=False),
}

for k, p in PRESETS.items():
    Image.fromarray(render(p), 'RGBA').save(os.path.join(V2, f'muyu_3d_{k}.png'), optimize=True)
    print('rendered', k)

# 对比图
CELL = 384; BAR = 40; PAD = 14; ck = 16
c1, c2 = (58, 54, 46), (74, 70, 60)
items = [('原版 Original', np.dstack([np.asarray(_src.convert('RGB')), _alpha512]))] + \
        [(p['label'], render(p)) for p in PRESETS.values()]
cols = 2; rows = (len(items) + cols - 1) // cols
MW = cols * CELL + (cols + 1) * PAD; MH = rows * (CELL + BAR) + (rows + 1) * PAD
canvas = Image.new('RGB', (MW, MH), (24, 22, 16)); draw = ImageDraw.Draw(canvas)


def load_font(sz):
    for fp in ['C:/Windows/Fonts/msyh.ttc', 'C:/Windows/Fonts/msyh.ttf', 'C:/Windows/Fonts/arial.ttf']:
        if os.path.exists(fp):
            try:
                return ImageFont.truetype(fp, sz)
            except Exception:
                pass
    return ImageFont.load_default()


for i, (label, img) in enumerate(items):
    r, c = divmod(i, cols); x0 = PAD + c * (CELL + PAD); y0 = PAD + r * (CELL + BAR + PAD)
    draw.rectangle([x0, y0, x0 + CELL, y0 + BAR], fill=(249, 202, 36))
    draw.text((x0 + 12, y0 + BAR // 2), label, fill=(26, 26, 10), font=load_font(20), anchor='lm')
    bx, by = x0, y0 + BAR
    for gy2 in range(by, by + CELL, ck):
        for gx2 in range(x0, x0 + CELL, ck):
            draw.rectangle([gx2, gy2, min(gx2 + ck, x0 + CELL), min(gy2 + ck, by + CELL)],
                           fill=c1 if ((gx2 // ck + gy2 // ck) % 2 == 0) else c2)
    thumb = Image.fromarray(img, 'RGBA').resize((CELL - 24, CELL - 24), Image.LANCZOS)
    canvas.paste(thumb, (x0 + 12, by + 12), thumb)
canvas.save(os.path.join(V2, 'muyu_3d_compare.png'), optimize=True)
print('montage saved', os.path.getsize(os.path.join(V2, 'muyu_3d_compare.png')) // 1024, 'KB')
