#!/usr/bin/env python3
"""生成 DMG 背景图 Resources/dmg-background.png。

画布 1320x800 @144dpi，对应 Finder 窗口 660x400pt。
图标位置与 make_dmg.sh 的 Finder 布局保持一致：
WarpCursor.app 在 (185,175)pt，Applications 在 (475,175)pt，图标 128pt。
内容整体偏上，给窗口底部留出余量（标题栏/状态条会压缩实际可见高度，
贴底的文字会被盖住）。
背景只画两个图标之间的箭头和底部提示文字，其余留白。
"""
import os

from PIL import Image, ImageDraw, ImageFont

W, H = 1320, 800
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "Resources", "dmg-background.png"))

# 中文字体候选：macOS 优先苹方，Linux 用 Noto CJK；都找不到时退回默认字体（仅英文行可读）
CANDIDATE_FONTS = [
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/STHeiti Medium.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc",
]


def load_font(size):
    for path in CANDIDATE_FONTS:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def main():
    # 浅色竖向渐变背景
    top = (251, 251, 252)
    bottom = (236, 238, 243)
    img = Image.new("RGB", (W, H), top)
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        c = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (W, y)], fill=c)

    # 箭头：图标中心 y=350px，位于左侧 App 图标与右侧 Applications 图标之间
    arrow = (148, 163, 184)
    y = 350
    d.rounded_rectangle([545, y - 16, 742, y + 16], radius=16, fill=arrow)
    d.polygon([(735, y - 42), (812, y), (735, y + 42)], fill=arrow)

    # 底部提示文字（居中）
    zh = "将 WarpCursor 拖到 Applications 即可安装"
    en = "Drag WarpCursor into Applications to install"
    d.text((W / 2, 556), zh, font=load_font(40), fill=(104, 112, 128), anchor="ma")
    d.text((W / 2, 610), en, font=load_font(29), fill=(152, 159, 171), anchor="ma")

    img.save(OUT, dpi=(144, 144))
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
