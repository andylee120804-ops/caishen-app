# 木鱼 img2img 候选：抠图 → 与原始轮廓对比（纵横比 1.33）→ 选形最接近者落位
from PIL import Image
import os, shutil

V2 = 'entry/src/main/resources/rawfile/props/_v2_muyu'
PROPS = 'entry/src/main/resources/rawfile/props'

# 原始素材轮廓参考（纵横比）

def cut(key):
    from rembg import remove
    src = f'{V2}/{key}.jpg'
    if not os.path.exists(src):
        print(f'  ✗ {src} 不存在')
        return None
    im = remove(Image.open(src).convert('RGBA'))
    alpha = im.getchannel('A')
    b = alpha.point(lambda v: 255 if v > 20 else 0).getbbox()
    cw, ch = b[2] - b[0], b[3] - b[1]
    aspect = cw / ch
    content = im.crop(b)
    side = max(cw, ch)
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.paste(content, ((side - cw) // 2, (side - ch) // 2), content)
    out = canvas.resize((512, 512), Image.LANCZOS)
    out.save(f'{V2}/{key}_cut.png', optimize=True)
    print(f'  {key}: bbox={b} aspect={aspect:.2f} (原始=1.33) {os.path.getsize(f"{V2}/{key}_cut.png")//1024}KB')
    return aspect

if __name__ == '__main__':
    print('== 抠图 + 轮廓对比 ==')
    results = {k: cut(k) for k in ['muyu_i2i_a', 'muyu_i2i_b']}
    valid = {k: v for k, v in results.items() if v is not None}
    if not valid:
        print('无可用候选')
        raise SystemExit(0)
    target = 1.331
    best = min(valid, key=lambda k: abs(valid[k] - target))
    print(f'== 落位 {best}（形最接近原始） ==')
    shutil.copy(f'{V2}/{best}_cut.png', f'{PROPS}/muyu.png')
    print('muyu.png updated')
    import subprocess
    print('done')