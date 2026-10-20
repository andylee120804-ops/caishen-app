# 自绘金元宝 Tab 图标（256×256 RGBA，透明底）
# 造型：元宝船身 + 中央鼓包 + 两端翘角，金渐变 + 高光 + 深金描边
from PIL import Image, ImageDraw, ImageFilter

S = 256


def make_yuanbao():
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    # 内径形状（先画深金描边层 = 外扩 3px 的剪影）
    def shape(expand=0):
        d.ellipse([48 - expand, 116 - expand, 208 + expand, 188 + expand], fill=(138, 90, 18, 235))  # 船身
        d.ellipse([24 - expand, 100 - expand, 112 + expand, 172 + expand], fill=(138, 90, 18, 235))   # 左翘角
        d.ellipse([144 - expand, 100 - expand, 232 + expand, 172 + expand], fill=(138, 90, 18, 235))  # 右翘角
        d.ellipse([88 - expand, 64 - expand, 168 + expand, 156 + expand], fill=(138, 90, 18, 235))    # 中央鼓包

    shape(3)

    # 主体分层填充（亮→暗 立体感）
    d.ellipse([48, 116, 208, 188], fill=(242, 201, 76, 255))   # 船身高亮带
    d.ellipse([44, 128, 212, 194], fill=(217, 154, 43, 255))   # 船身主金
    d.ellipse([24, 100, 112, 172], fill=(228, 178, 62, 255))   # 左翘角
    d.ellipse([144, 100, 232, 172], fill=(228, 178, 62, 255))  # 右翘角
    d.ellipse([88, 64, 168, 156], fill=(250, 220, 110, 255))   # 鼓包亮金
    d.ellipse([98, 78, 158, 140], fill=(255, 235, 150, 255))   # 鼓包高光区

    # 顶部高光（柔光斑）
    hl = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    dhl = ImageDraw.Draw(hl)
    dhl.ellipse([106, 72, 150, 100], fill=(255, 250, 220, 210))
    hl = hl.filter(ImageFilter.GaussianBlur(6))
    im = Image.alpha_composite(im, hl)

    # 底部暗部（左下方微影，增加体积）
    sh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    dsh = ImageDraw.Draw(sh)
    dsh.ellipse([54, 150, 150, 196], fill=(120, 74, 12, 110))
    sh = sh.filter(ImageFilter.GaussianBlur(10))
    im = Image.alpha_composite(im, sh)

    return im


if __name__ == '__main__':
    out = 'entry/src/main/resources/rawfile/props/yuanbao.png'
    im = make_yuanbao()
    im.save(out, optimize=True)
    b = im.getchannel('A').point(lambda v: 255 if v > 20 else 0).getbbox()
    import os
    print(out, im.size, 'bbox:', b, os.path.getsize(out) // 1024, 'KB')