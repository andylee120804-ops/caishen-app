# 新五神抠图 + 资源落位：
# 1) _v2/{name}.jpg → rembg 抠图 → _v2/{name}.png（PNG 自带 1024→512 缩放）
# 2) 落位 rawfile/deities/1-5.png（1王亥 2比干 3关羽 4柴荣 5赵公明）
# 3) 落位 base/media/deity_1-5.png（192×192，桌面卡片用）
# 4) 同步 1-5.jpg 原始图
from PIL import Image
import os, shutil

RAW = 'entry/src/main/resources/rawfile/deities'
OUT = f'{RAW}/_v2'
MEDIA = 'entry/src/main/resources/base/media'

SLOTS = [('wanghai', '王亥'), ('bigan', '比干'), ('guanyu', '关羽'), ('chairong', '柴荣'), ('zhaogongming', '赵公明')]


def cutout(key):
    src = f'{OUT}/{key}.jpg'
    dst = f'{OUT}/{key}.png'
    if os.path.exists(dst):
        print(f'  skip (已抠): {dst}')
        return
    if not os.path.exists(src):
        raise FileNotFoundError(src)
    from rembg import remove
    im = Image.open(src).convert('RGBA')
    out = remove(im)
    out = out.resize((512, 512), Image.LANCZOS)
    out.save(dst, optimize=True)
    b = out.getchannel('A').point(lambda v: 255 if v > 20 else 0).getbbox()
    print(f'  ✓ {dst} bbox={b}')


if __name__ == '__main__':
    print('== 抠图 ==')
    for key, name in SLOTS:
        try:
            cutout(key)
        except FileNotFoundError:
            print(f'  ✗ {name} 原图未生成，跳过')
        except Exception as e:
            print(f'  ✗ {name} 抠图失败: {e}')
    print('== 落位 rawfile/deities ==')
    for i, (key, name) in enumerate(SLOTS, start=1):
        src = f'{OUT}/{key}.png'
        jpg = f'{OUT}/{key}.jpg'
        if os.path.exists(src):
            shutil.copy(src, f'{RAW}/{i}.png')
            print(f'  ✓ {RAW}/{i}.png <- {name}')
        if os.path.exists(jpg):
            shutil.copy(jpg, f'{RAW}/{i}.jpg')
            print(f'  ✓ {RAW}/{i}.jpg <- {name}')
    print('== 落位 media（桌面卡片 192） ==')
    for i, (key, name) in enumerate(SLOTS, start=1):
        src = f'{OUT}/{key}.png'
        if os.path.exists(src):
            im = Image.open(src).resize((192, 192), Image.LANCZOS)
            im.save(f'{MEDIA}/deity_{i}.png', optimize=True)
            print(f'  ✓ {MEDIA}/deity_{i}.png <- {name}')
    print('done')