# 五路财神 App 图标批量生成（1024/512, PNG+JPG）
# 每个神像 × 两种背景风格（A 暖金底 / B 深色底+金色光晕），按各自透明通道 bbox 自适应居中。
from PIL import Image, ImageDraw, ImageFilter
import math, os

SIZE = 1024
D = 'entry/src/main/resources/rawfile/deities'
OUT = 'scripts/app-icon'

DEITIES = [
    ('1.png', '1-wanghai', '王亥'),
    ('2.png', '2-bigan', '比干'),
    ('3.png', '3-guanyu', '关羽'),
    ('4.png', '4-chairong', '柴荣'),
    ('5.png', '5-zhaogongming', '赵公明'),
]


def deity_bbox(deity):
    alpha = deity.getchannel('A')
    return alpha.point(lambda v: 255 if v > 20 else 0).getbbox()


def radial_gradient(stops):
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


def placed(deity, target_max, y_center):
    """按 bbox 等比缩放：最长边=target_max，内容中心落在 y_center。返回 (scaled, dx, dy, dw, dh)"""
    b = deity_bbox(deity)
    bw, bh = b[2] - b[0], b[3] - b[1]
    k = target_max / max(bw, bh)
    dw = int(deity.width * k)
    dh = int(deity.height * k)
    scaled = deity.resize((dw, dh), Image.LANCZOS)
    cx = b[0] + bw / 2
    cy = b[1] + bh / 2
    dx = int(SIZE / 2 - cx * k)
    dy = int(y_center - cy * k)
    return scaled, dx, dy, dw, dh


def style_a(deity, target_max, y_center):
    bg = radial_gradient([
        (0.00, (251, 226, 152)),
        (0.45, (233, 186, 96)),
        (0.80, (201, 141, 62)),
        (1.00, (164, 96, 38)),
    ])
    im = add_vignette(bg, 70).convert('RGBA')
    scaled, dx, dy, dw, dh = placed(deity, target_max, y_center)
    d = ImageDraw.Draw(im, 'RGBA')
    ew = int(max(dw, dh) * 0.52)
    eh = int(dh * 0.07)
    d.ellipse([(SIZE - ew) // 2, dy + dh - eh, (SIZE + ew) // 2, dy + dh], fill=(70, 36, 12, 200))
    im.alpha_composite(scaled, (dx, dy))
    d.ellipse([30, 30, SIZE - 30, SIZE - 30], outline=(120, 66, 14, 170), width=5)
    return im


def style_b(deity, target_max, y_center):
    bg = radial_gradient([
        (0.00, (70, 56, 24)),
        (0.50, (42, 37, 16)),
        (1.00, (22, 21, 8)),
    ])
    im = bg.convert('RGBA')
    scaled, dx, dy, dw, dh = placed(deity, target_max, y_center)
    halo = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    halo.alpha_composite(scaled, (dx, dy))
    gold = Image.new('RGBA', (SIZE, SIZE), (249, 202, 36, 0))
    gold.putalpha(halo.getchannel('A'))
    gold = gold.filter(ImageFilter.GaussianBlur(52))
    gold = Image.eval(gold, lambda v: min(255, v + 48))
    im.alpha_composite(gold)
    im.alpha_composite(scaled, (dx, dy))
    return im


def save_variants(im, key):
    p1024 = f'{OUT}/{key}-1024.png'
    p512 = f'{OUT}/{key}-512.png'
    pjpg = f'{OUT}/{key}-512.jpg'
    im.save(p1024, optimize=True)
    im.resize((512, 512), Image.LANCZOS).save(p512, optimize=True)
    Image.open(p1024).convert('RGB').resize((512, 512), Image.LANCZOS).save(pjpg, quality=90, optimize=True)
    print(f'{p1024} {os.path.getsize(p1024)//1024}KB')


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for f, key, name in DEITIES:
        deity = Image.open(f'{D}/{f}').convert('RGBA')
        b = deity_bbox(deity)
        # 内容占比越大，占满比例越高；长条全身像限制高度，避免顶圈
        coverage = (b[2] - b[0]) * (b[3] - b[1]) / (deity.width * deity.height)
        target_max = int(SIZE * (0.68 + coverage * 0.08))
        save_variants(style_a(deity, target_max, 475), f'{key}-gold')
        save_variants(style_b(deity, target_max, 475), f'{key}-dark')
        print(f'{name} bbox={b} target={target_max}')
    print('done')