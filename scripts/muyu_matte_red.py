# 木鱼换色: 哑光暗红(去亮漆感) + 嘴缝黄线消除
# 管线: 原图 V -> FFT 低通去鳞纹 -> 直方图匹配恢复形体 -> 嘴缝 AO 压暗 -> 哑光红 ramp
# 用法: python scripts/muyu_matte_red.py
from PIL import Image
import numpy as np
from scipy import ndimage
import hashlib
import os

GOLD = r'entry/src/main/resources/rawfile/props/_v2_muyu/orig/muyu_gold_512_0.png'
CUT253 = 'muyu_cut.png'
TARGETS = [
    r'entry/src/main/resources/rawfile/props/muyu.png',
    r'entry/src/main/resources/base/media/muyu.png',
    r'entry/build/default/intermediates/res/default/resources/rawfile/props/muyu.png',
    r'entry/build/default/intermediates/res/default/resources/base/media/muyu.png',
]

# 哑光暗红 ramp (枣红/绛红, 无金色高光)
VP = [0.00, 0.30, 0.45, 0.60, 0.75, 0.90, 1.00]
RP = [35, 55, 80, 108, 138, 162, 182]
GP = [8, 14, 21, 31, 43, 55, 70]
BP = [5, 9, 13, 19, 26, 33, 44]


def clean_v(a, rc, ao_iters, ao_depth):
    """alpha 不变, 返回去纹+缝压暗后的 V"""
    m = a[..., 3] > 8
    V = a[..., :3].max(axis=2)
    # 外延防边缘渗入
    _, idx = ndimage.distance_transform_edt(~m, return_indices=True)
    Vext = V[idx[0].astype(np.intp), idx[1].astype(np.intp)]
    # FFT 低通去鳞纹
    h, w = Vext.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    fr = np.hypot(fy, fx)
    keep = 1.0 / (1.0 + (fr / rc) ** 8)
    Vc = np.fft.ifft2(np.fft.fft2(Vext) * keep).real
    # 直方图匹配回原色调分布
    q = np.linspace(0, 100, 512)
    sq = np.maximum.accumulate(np.percentile(Vc[m], q))
    rq = np.percentile(V[m], q)
    Vf = np.interp(Vc, sq, rq)
    # 轮廓/嘴缝边缘 10px 回归原图
    dist_in = ndimage.distance_transform_edt(m)
    wgt = np.clip((dist_in - 2) / 8.0, 0, 1)
    Vf = np.where(m, wgt * Vf + (1 - wgt) * V, 0)
    # 嘴缝检测: 闭运算填缝, slit = 被填上的透明区
    slit = ndimage.binary_closing(m, iterations=ao_iters) & ~m
    # 缝周 AO 压暗(洞壁应是暗的)
    if slit.sum() > 0:
        d = ndimage.distance_transform_edt(~slit)
        f = 1.0 - ao_depth * np.clip(1.0 - d / 8.0, 0, 1)
        Vf = np.where(m, Vf * f, 0)
    return Vf, a[..., 3]


def recolor(Vf, alpha):
    R = np.interp(Vf, np.array(VP) * 255, RP)
    G = np.interp(Vf, np.array(VP) * 255, GP)
    B = np.interp(Vf, np.array(VP) * 255, BP)
    return Image.fromarray(np.dstack([R, G, B, alpha]).astype(np.uint8), 'RGBA')


def main():
    # --- 512 主资源 ---
    gold_im = Image.open(GOLD)
    gold = np.asarray(gold_im.convert('RGBA')).astype(float)
    Vf, alpha = clean_v(gold, rc=5 / 512, ao_iters=20, ao_depth=0.6)
    out = recolor(Vf, alpha)
    for t in TARGETS:
        out.save(t)
        print('saved', t, hashlib.md5(open(t, 'rb').read()).hexdigest()[:10])

    # --- 253 交付物(等效参数按宽度缩放) ---
    cut = Image.open(CUT253)
    ca = np.asarray(cut.convert('RGBA')).astype(float)
    ys, xs = np.where(ca[..., 3] > 8)
    bw = xs.max() - xs.min() + 1
    Vc, ac = clean_v(ca, rc=1.0 / (102.0 * bw / 450.0), ao_iters=9, ao_depth=0.6)
    r253 = recolor(Vc, ac)
    r253.save('muyu_red_lacquer.png')
    r253.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)).save('muyu_red_lacquer_cropped.png')
    print('saved root deliverables')

    # --- 对比图 ---
    bg = Image.new('RGBA', (512 * 2 + 48, 512 + 32), (26, 26, 10, 255))
    bg.paste(gold_im, (16, 16), gold_im)
    bg.paste(out, (512 + 32, 16), out)
    bg.convert('RGB').save('muyu_compare.png')
    print('saved muyu_compare.png')

    # --- 验证 ---
    oa = np.asarray(out).astype(float)
    m = oa[..., 3] > 8
    px = oa[..., :3][m]
    print('fish mean RGB=%s (target matte ~[105,30,18])' % px.mean(axis=0).round(1))
    yellowish = (px[:, 1] > 95) & ((px[:, 1] - px[:, 2]) > 45)
    print('yellowish px: %d (was many)' % yellowish.sum())
    print('alpha identical:', np.array_equal(oa[..., 3].astype(np.uint8), gold[..., 3].astype(np.uint8)))


if __name__ == '__main__':
    main()
