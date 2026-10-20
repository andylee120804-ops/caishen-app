# 木鱼素材 v2 落位：rembg 抠图 → 512 方形画布（自然比例）→ 备份旧图 → 选优安装
from PIL import Image
import os, shutil

V2 = 'entry/src/main/resources/rawfile/props/_v2_muyu'
PROPS = 'entry/src/main/resources/rawfile/props'


def cut(key):
    from rembg import remove
    src = f'{V2}/{key}.jpg'
    if not os.path.exists(src):
        print(f'  ✗ {src} 不存在')
        return None
    im = remove(Image.open(src).convert('RGBA'))
    alpha = im.getchannel('A')
    b = alpha.point(lambda v: 255 if v > 20 else 0).getbbox()
    print(f'  {key}: bbox={b} size={b[2]-b[0]}x{b[3]-b[1]} aspect={(b[2]-b[0])/(b[3]-b[1]):.2f}')
    content = im.crop(b)
    cw, ch = content.size
    side = max(cw, ch)
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.paste(content, ((side - cw) // 2, (side - ch) // 2), content)
    out = canvas.resize((512, 512), Image.LANCZOS)
    out.save(f'{V2}/{key}_cut.png', optimize=True)
    coverage = (cw * ch) / (im.width * im.height)
    print(f'  ✓ {key}_cut.png 512x512 coverage={coverage:.2f} {os.path.getsize(f"{V2}/{key}_cut.png")//1024}KB')
    return coverage


if __name__ == '__main__':
    os.makedirs(f'{V2}/orig', exist_ok=True)
    print('== 抠图 ==')
    results = {}
    for key in ['muyu_a', 'muyu_b']:
        results[key] = cut(key)
    print('== 备份旧素材 ==')
    if not os.path.exists(f'{V2}/orig/muyu_v1.png'):
        shutil.copy(f'{PROPS}/muyu.png', f'{V2}/orig/muyu_v1.png')
        print('  ✓ muyu_v1.png')
    if results['muyu_a'] is None and results['muyu_b'] is None:
        print('无可用候选，结束')
        raise SystemExit(0)
    print('done')