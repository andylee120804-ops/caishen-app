# 大殿背景修图 v2 - 基于 hall_s403.jpg 的测量驱动修补：
#   0. numpy 定位中央金色浮雕 bbox（亮金像素检测）
#   1. 浮雕 -> 横向克隆左侧同行的干净墙面填补（保持纵向渐变连续）
#   2. 右下角水印 -> 克隆其左侧地面覆盖
#   3. 裁掉两侧窗带（x 61~459）-> 左右镜像外扩回 522 宽（对称列柱，接缝天然连续）
# 输出：tmp/hall-candidates/hall_bg_clean.png
# 用法：py -3 scripts/fix-hall-bg.py           # 完整修补
#       py -3 scripts/fix-hall-bg.py --debug   # 只画检测框核对坐标，不改图

from PIL import Image
import numpy as np
import os

SRC = os.path.join(os.path.dirname(__file__), '../tmp/hall-candidates/hall_s403.jpg')
DST = os.path.join(os.path.dirname(__file__), '../tmp/hall-candidates/hall_bg_clean.png')

CROP_X0, CROP_X1 = 68, 452   # 两侧窗带/亮条之外（含窗光溢出余量）
OUT_W = 522                  # 390:844 ≈ 0.462 -> 522x1132


def ramp_mask(w, h, feather, side):
    """单侧羽化掩膜：side='l' 左缘渐入 / 'r' 右缘渐出 / 'v' 上下缘渐变。"""
    m = np.full((h, w), 255, dtype=np.uint8)
    ramp = np.linspace(0, 255, feather).astype(np.uint8)
    if side == 'r':
        m[:, -feather:] = ramp[::-1]
    elif side == 'v':
        m[:feather, :] = np.minimum(m[:feather, :], ramp[:, None])
        m[-feather:, :] = np.minimum(m[-feather:, :], ramp[::-1][:, None])
    else:
        m[:, :feather] = ramp
    return Image.fromarray(m)


def main():
    img = Image.open(SRC).convert('RGB')
    W, H = img.size
    print(f'源图 {W}x{H}')
    arr = np.asarray(img).astype(int)

    # ── 0. 测量中央金色浮雕 bbox（亮金：R 高 G 中 B 低；限制在墙带内，避开地面）──
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    gold = (r > 200) & (g > 130) & (b < 115) & (r - b > 110)
    region = np.zeros_like(gold)
    region[400:870, 200:360] = True  # 只在中央墙带内找（y<870 避开地面）
    ys, xs = np.where(gold & region)
    if len(ys) == 0:
        raise SystemExit('未检测到金色浮雕，请调整检测区域')
    ex0, ex1, ey0, ey1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
    print(f'浮雕 bbox: x {ex0}~{ex1}, y {ey0}~{ey1}')

    # debug：画出检测框/克隆源/裁切线，供人工核对
    dbg = img.copy()
    from PIL import ImageDraw
    d = ImageDraw.Draw(dbg)
    d.rectangle((ex0, ey0, ex1, ey1), outline=(0, 255, 0), width=3)          # 浮雕
    src_x0 = max(ex0 - (ex1 - ex0) - 20, 130)
    d.rectangle((src_x0, ey0, ex0 - 8, ey1), outline=(0, 160, 255), width=3) # 克隆源
    d.line((CROP_X0, 0, CROP_X0, H), fill=(255, 0, 255), width=2)            # 裁切线
    d.line((CROP_X1, 0, CROP_X1, H), fill=(255, 0, 255), width=2)
    d.rectangle((380, 1072, 470, H), outline=(255, 255, 0), width=2)         # 水印
    dbg.save(DST.replace('hall_bg_clean.png', '_debug.png'))
    print('debug 已保存（绿=浮雕框 蓝=克隆源 紫=裁切线 黄=水印框）')
    if '--debug' in __import__('sys').argv:
        return

    # ── 1. 横向克隆左侧墙面填补浮雕（检测框只是最亮核心，按 debug 核对外扩盖住暗部）──
    px0, py0 = max(ex0 - 16, 0), max(ey0 - 58, 0)
    px1, py1 = min(ex1 + 22, W - 1), min(ey1 + 98, H - 1)
    src_x0 = max(px0 - 90, 150)          # 克隆源：浮雕左侧的干净墙板（同行，保纵向渐变）
    tile_w = px0 - 10 - src_x0
    x = px0 - 4
    while x < px1:
        w = min(tile_w, px1 + 4 - x)
        if w <= 0:
            break
        patch = img.crop((src_x0, py0, src_x0 + w, py1))
        img.paste(patch, (x, py0), ramp_mask(w, patch.size[1], min(14, w // 2), 'l'))
        x += max(w - 14, 4)  # 重叠羽化区推进（保证前进，避免死循环）

    # 色调匹配：把补丁区亮度调到与左右两侧墙面一致，消除"暗门"感
    img_arr = np.asarray(img).astype(float)
    orig_arr = np.asarray(Image.open(SRC).convert('RGB')).astype(float)
    ring = np.concatenate([orig_arr[py0:py1, src_x0:px0 - 10].reshape(-1, 3),
                           orig_arr[py0:py1, px1 + 12:px1 + 92].reshape(-1, 3)])
    patched = img_arr[py0:py1, px0:px1].reshape(-1, 3)
    gain = np.clip(ring.mean(axis=0) / max(patched.mean(axis=0).mean(), 1), 0.85, 1.3)
    fh = min(30, (py1 - py0) // 3)
    soft = np.ones((py1 - py0, px1 - px0), dtype=float)
    rv = np.linspace(0, 1, fh)
    soft[:fh, :] *= rv[:, None]
    soft[-fh:, :] *= rv[::-1][:, None]
    soft[:, :fh] *= rv[None, :]
    soft[:, -fh:] *= rv[::-1][None, :]
    img_arr[py0:py1, px0:px1] = img_arr[py0:py1, px0:px1] * (1 - soft[..., None]) \
        + np.clip(img_arr[py0:py1, px0:px1] * gain, 0, 255) * soft[..., None]
    img = Image.fromarray(img_arr.astype(np.uint8))
    arr = np.asarray(img)

    # ── 2. 右下角水印 -> 克隆其左侧地面（盖满到裁切线外，避免镜像放大残留）──
    wm = (365, 1055, 485, H)
    pw2, ph2 = wm[2] - wm[0], wm[3] - wm[1]
    patch = img.crop((wm[0] - 120, wm[1], wm[0] - 120 + pw2, wm[3]))
    m2 = np.full((ph2, pw2), 255, dtype=np.uint8)
    ramp2 = np.linspace(0, 255, 16).astype(np.uint8)
    m2[:, :16] = ramp2            # 仅左缘羽化
    m2[:14, :] = np.minimum(m2[:14, :], np.linspace(0, 255, 14).astype(np.uint8)[:, None])
    img.paste(patch, (wm[0], wm[1]), Image.fromarray(m2))

    # ── 3. 裁中央净区 -> 镜像外扩 ──
    core = img.crop((CROP_X0, 0, CROP_X1, H))  # 398 宽
    pad_l = (OUT_W - core.size[0]) // 2        # 62
    pad_r = OUT_W - core.size[0] - pad_l
    canvas = Image.new('RGB', (OUT_W, H))
    canvas.paste(core, (pad_l, 0))
    canvas.paste(core.crop((0, 0, pad_l, H)).transpose(Image.FLIP_LEFT_RIGHT), (0, 0))
    canvas.paste(core.crop((core.size[0] - pad_r, 0, core.size[0], H)).transpose(Image.FLIP_LEFT_RIGHT),
                 (OUT_W - pad_r, 0))

    canvas.save(DST)
    print(f'已保存 {DST} {canvas.size[0]}x{canvas.size[1]}')


if __name__ == '__main__':
    main()
