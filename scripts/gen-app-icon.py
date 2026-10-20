# 生成备案用 App 图标（1024/512, PNG+JPG），素材为已验证的赵公明神像（deities/1.png）
# 变体 A：暖金底（贴合现有 app_icon 金色主调）
# 变体 B：深色底 #1a1a0a + 金色光晕（贴合 App UI 主题）
from PIL import Image, ImageDraw, ImageFilter
import math, os

SIZE = 1024
SRC = 'entry/src/main/resources/rawfile/deities/1.png'
OUT = 'scripts/app-icon'


def radial_gradient(stops):
    """stops: [(t, (r,g,b))...]，t=0 中心 → 1 边缘"""
    cx = cy = SIZE / 2
    maxd = math.hypot(cx, cy)
    im = Image.new('RGB', (SIZE, SIZE))
    px = im.load()
    for y in range(SIZE):
        for x in range(SIZE):
            t = math.hypot(x - cx, y - cy) / maxd
            for i in range(len(stops) - 1):
                t0, c0 = stops[i]
                t1, c1 = stops[i + 1]
                if t <= t1:
                    k = (t - t0) / (t1 - t0)
                    px[x, y] = tuple(int(c0[j] + (c1[j] - c0[j]) * k) for j in range(3))
                    break
            else:
                px[x, y] = stops[-1][1]
    return im


def add_vignette(im, strength):
    mask = Image.new('L', (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).ellipse([-SIZE * 0.3, -SIZE * 0.3, SIZE * 1.3, SIZE * 1.3], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(SIZE * 0.30))
    dark = Image.new('RGB', (SIZE, SIZE), (26, 18, 6))
    return Image.composite(Image.blend(im, dark, strength / 255), im, mask)


def place_deity(im, deity, scale_w, y_center):
    """神像居中放置，返回 (dx, dy, dw, dh)"""
    dw = scale_w
    dh = int(deity.height * scale_w / deity.width)
    dx = (SIZE - dw) // 2
    dy = y_center - dh // 2
    im.alpha_composite(deity.resize((dw, dh), Image.LANCZOS), (dx, dy))
    return dx, dy, dw, dh


def variant_a():
    """暖金底：中心亮 → 边缘深铜，暗角 + 接地影 + 细描边圈"""
    bg = radial_gradient([
        (0.00, (251, 226, 152)),
        (0.45, (233, 186, 96)),
        (0.80, (201, 141, 62)),
        (1.00, (164, 96, 38)),
    ])
    im = add_vignette(bg, 70).convert('RGBA')
    deity = Image.open(SRC).convert('RGBA')
    dx, dy, dw, dh = place_deity(im, deity, 680, 470)
    # 接地影
    d = ImageDraw.Draw(im, 'RGBA')
    ew = int(dw * 0.56)
    eh = int(dh * 0.09)
    d.ellipse([(SIZE - ew) // 2, dy + dh - eh, (SIZE + ew) // 2, dy + dh], fill=(70, 36, 12, 200))
    # 贴边细描边圈（不压神像）
    d.ellipse([30, 30, SIZE - 30, SIZE - 30], outline=(120, 66, 14, 170), width=5)
    return im


def variant_b():
    """深色底 #1a1a0a + 金色光晕（神像剪影模糊垫底）"""
    bg = radial_gradient([
        (0.00, (70, 56, 24)),
        (0.50, (42, 37, 16)),
        (1.00, (22, 21, 8)),
    ])
    im = bg.convert('RGBA')
    deity = Image.open(SRC).convert('RGBA')
    scale_w = 660
    dh = int(deity.height * scale_w / deity.width)
    dx = (SIZE - scale_w) // 2
    dy = 470 - dh // 2
    scaled = deity.resize((scale_w, dh), Image.LANCZOS)
    # 光晕：神像 alpha 剪影 → 金色 → 大模糊
    halo = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    halo.alpha_composite(scaled, (dx, dy))
    gold = Image.new('RGBA', (SIZE, SIZE), (249, 202, 36, 0))
    gold.putalpha(halo.getchannel('A'))
    gold = gold.filter(ImageFilter.GaussianBlur(52))
    gold = Image.eval(gold, lambda v: min(255, v + 48))
    im.alpha_composite(gold)
    im.alpha_composite(scaled, (dx, dy))
    return im


def save_variants(im, name):
    p1024 = f'{OUT}/{name}-1024.png'
    p512 = f'{OUT}/{name}-512.png'
    pjpg = f'{OUT}/{name}-512.jpg'
    im.save(p1024, optimize=True)
    im.resize((512, 512), Image.LANCZOS).save(p512, optimize=True)
    Image.open(p1024).convert('RGB').resize((512, 512), Image.LANCZOS).save(pjpg, quality=90, optimize=True)
    print(p1024, os.path.getsize(p1024) // 1024, 'KB')
    print(p512, os.path.getsize(p512) // 1024, 'KB')
    print(pjpg, os.path.getsize(pjpg) // 1024, 'KB')


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    save_variants(variant_a(), 'icon-a-gold')
    save_variants(variant_b(), 'icon-b-dark')
    print('done')