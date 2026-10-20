# 求签签支高清重绘（28×216，红漆身+金冠头+竖高光），替换 13×100 旧素材
from PIL import Image, ImageDraw
import math

W, H = 28, 216
im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
px = im.load()

BODY_TOP, BODY_BOT = 34, H - 14      # 签身范围（顶部留金冠）
BODY_L, BODY_R = 7, 21               # 签身宽 14
GOLD_TOP, GOLD_BOT = 2, BODY_TOP     # 金冠头
BAND_TOP, BAND_BOT = 34, 44          # 颈下金箍

for y in range(H):
    for x in range(W):
        # 金冠头：亮金渐变
        if GOLD_TOP <= y < GOLD_BOT and 6 <= x <= 21:
            k = (y - GOLD_TOP) / (GOLD_BOT - GOLD_TOP)
            base = (240 + int(8 * k), 197 + int(10 * k), 70 + int(20 * k))
            px[x, y] = (*base, 255)
            continue
        # 金箍
        if BAND_TOP <= y < BAND_BOT and BODY_L - 2 <= x <= BODY_R + 2:
            px[x, y] = (238, 196, 74, 255)
            continue
        # 红漆签身
        if BODY_TOP <= y < BODY_BOT and BODY_L <= x <= BODY_R:
            # 横向光泽：左侧高光 → 右侧暗部
            t = (x - BODY_L) / (BODY_R - BODY_L)
            shine = math.exp(-((t - 0.32) ** 2) / 0.012)
            base_r = 132 + int(96 * shine)      # 暗红→亮红
            base_g = 22 + int(34 * shine)
            base_b = 16 + int(30 * shine)
            # 上下明暗：两端微暗
            vk = 1.0 - 0.10 * min(abs(y - BODY_TOP), abs(BODY_BOT - y)) / max(1, (BODY_BOT - BODY_TOP) / 2)
            px[x, y] = (int(base_r * vk), int(base_g * vk), int(base_b * vk), 255)
            continue
        # 顶部/底部圆头（横向渐变同样处理）
        if y < BODY_TOP and 8 <= x <= 20:
            t = (x - 8) / 12
            shine = math.exp(-((t - 0.35) ** 2) / 0.015)
            px[x, y] = (132 + int(96 * shine), 22 + int(30 * shine), 16 + int(26 * shine), 255)
        if y >= BODY_BOT and 8 <= x <= 20:
            px[x, y] = (118, 18, 12, 255)

im.save('entry/src/main/resources/rawfile/props/_v2_qiu/stick_new.png', optimize=True)
b = im.getchannel('A').point(lambda v: 255 if v > 10 else 0).getbbox()
import os
print('stick_new.png', (W, H), 'bbox:', b, os.path.getsize('entry/src/main/resources/rawfile/props/_v2_qiu/stick_new.png'), 'bytes')