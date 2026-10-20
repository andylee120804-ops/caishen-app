# 求签素材 v2 落位：抠图 → 按原比例(0.563)留白 → 2x 分辨率 → 备份旧素材 → 生成预览
from PIL import Image
import os, shutil

V2 = 'entry/src/main/resources/rawfile/props/_v2_qiu'
PROPS = 'entry/src/main/resources/rawfile/props'
ASPECT = 272 / 483  # 原签筒素材宽高比


def cut_and_pad(key):
    from rembg import remove
    src = f'{V2}/{key}.jpg'
    if not os.path.exists(src):
        print(f'  ✗ {src} 不存在')
        return None
    im = remove(Image.open(src).convert('RGBA'))
    alpha = im.getchannel('A')
    b = alpha.point(lambda v: 255 if v > 20 else 0).getbbox()
    print(f'  {key}: bbox={b} aspect={((b[2]-b[0])/(b[3]-b[1])):.2f}')
    content = im.crop(b)
    cw, ch = content.size
    caspect = cw / ch
    if caspect >= ASPECT:
        # 内容更方/更宽：加高画布
        nh = int(cw / ASPECT)
        canvas = Image.new('RGBA', (cw, nh), (0, 0, 0, 0))
        canvas.paste(content, (0, (nh - ch) // 2), content)
    else:
        # 内容更高：加宽画布
        nw = int(ch * ASPECT)
        canvas = Image.new('RGBA', (nw, ch), (0, 0, 0, 0))
        canvas.paste(content, ((nw - cw) // 2, 0), content)
    out = canvas.resize((544, 966), Image.LANCZOS)
    out.save(f'{V2}/{key}_cut.png', optimize=True)
    coverage = (b[2] - b[0]) * (b[3] - b[1]) / (im.width * im.height)
    print(f'  ✓ {key}_cut.png {out.size} coverage={coverage:.2f} {os.path.getsize(f"{V2}/{key}_cut.png")//1024}KB')
    return coverage


if __name__ == '__main__':
    os.makedirs(f'{V2}/orig', exist_ok=True)
    print('== 抠图+留白 ==')
    results = {}
    for key in ['tube_a', 'tube_b']:
        results[key] = cut_and_pad(key)
    print('== 备份旧素材 ==')
    if not os.path.exists(f'{V2}/orig/qiu_art_v1.png'):
        shutil.copy(f'{PROPS}/qiu_art.png', f'{V2}/orig/qiu_art_v1.png')
        print('  ✓ qiu_art_v1.png')
    if not os.path.exists(f'{V2}/orig/qiu_stick_v1.png'):
        shutil.copy(f'{PROPS}/qiu_stick_pick.png', f'{V2}/orig/qiu_stick_v1.png')
        print('  ✓ qiu_stick_v1.png')
    if results['tube_a'] is None and results['tube_b'] is None:
        print('无可用候选，结束')
        raise SystemExit(0)
    print('done')