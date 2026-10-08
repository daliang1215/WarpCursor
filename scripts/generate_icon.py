#!/usr/bin/env python3
"""生成 WarpCursor 应用图标。

设计：深色圆角显示器框 + 屏幕内带残影拖尾的 warp 光标。
输出：Resources/AppIcon.icns（手工打包 PNG  entries，无需 macOS 的 iconutil）
      /tmp/warpcursor_icon_preview.png（预览图）
"""
import io
import struct
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT_ICNS = "Resources/AppIcon.icns"
OUT_MENUBAR = "Resources/MenuBarIcon.png"
OUT_PREVIEW = "/tmp/warpcursor_icon_preview.png"

# 经典光标箭头（朝左上），单位框 ~62x108
CURSOR_POLY = [(0, 0), (0, 100), (25, 78), (38, 108), (52, 101), (39, 71), (62, 68)]


def vgrad(w, h, stops):
    """多段垂直渐变。stops: [(pos0~1, (r,g,b)), ...]"""
    col = Image.new("RGB", (1, h))
    px = col.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        for i in range(len(stops) - 1):
            p0, c0 = stops[i]
            p1, c1 = stops[i + 1]
            if p0 <= t <= p1:
                f = (t - p0) / max(p1 - p0, 1e-6)
                px[0, y] = tuple(int(c0[k] + (c1[k] - c0[k]) * f) for k in range(3))
                break
    return col.resize((w, h))


def rounded_fill(canvas_size, bbox, radius, fill_img):
    layer = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    mask = Image.new("L", canvas_size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(bbox, radius=radius, fill=255)
    layer.paste(fill_img, (0, 0), mask)
    return layer


def draw_cursor(layer, scale, tx, ty, fill):
    pts = [(tx + x * scale, ty + y * scale) for x, y in CURSOR_POLY]
    ImageDraw.Draw(layer).polygon(pts, fill=fill)


def build_master():
    S = (SIZE, SIZE)
    canvas = Image.new("RGBA", S, (0, 0, 0, 0))

    # 1. 落地阴影
    sh = Image.new("RGBA", S, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([190, 848, 834, 948], fill=(0, 0, 0, 100))
    canvas = Image.alpha_composite(canvas, sh.filter(ImageFilter.GaussianBlur(48)))

    # 2. 底座 + 支架颈（深色渐变）
    stand_grad = vgrad(SIZE, SIZE, [(0, (58, 58, 76)), (1, (22, 22, 32))])
    neck = Image.new("RGBA", S, (0, 0, 0, 0))
    ImageDraw.Draw(neck).polygon([(468, 716), (556, 716), (584, 798), (440, 798)],
                                 fill=(255, 255, 255, 255))
    neck_masked = Image.new("RGBA", S, (0, 0, 0, 0))
    neck_masked.paste(stand_grad, (0, 0), neck.split()[0])
    canvas = Image.alpha_composite(canvas, neck_masked)
    base = rounded_fill(S, [368, 792, 656, 828], 17, stand_grad)
    canvas = Image.alpha_composite(canvas, base)

    # 3. 显示器边框
    bezel_grad = vgrad(SIZE, SIZE, [(0, (46, 46, 64)), (0.5, (30, 30, 44)), (1, (18, 18, 28))])
    bezel = rounded_fill(S, [104, 176, 920, 752], 58, bezel_grad)
    # 深色模式下与 Dock 分离的浅色描边
    ImageDraw.Draw(bezel).rounded_rectangle([104, 176, 920, 752], radius=58,
                                            outline=(255, 255, 255, 70), width=5)
    canvas = Image.alpha_composite(canvas, bezel)

    # 4. 屏幕（靛蓝→紫渐变）
    screen_grad = vgrad(SIZE, SIZE, [(0, (44, 50, 124)), (0.55, (74, 56, 181)), (1, (124, 77, 232))])
    screen = rounded_fill(S, [150, 222, 874, 706], 34, screen_grad)
    canvas = Image.alpha_composite(canvas, screen)

    # 屏幕径向光晕
    glow = Image.new("RGBA", S, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([110, 110, 630, 630], fill=(255, 255, 255, 30))
    canvas = Image.alpha_composite(canvas, glow.filter(ImageFilter.GaussianBlur(90)))

    # 斜向高光（裁剪到屏幕圆角内，保留自身透明度）
    sheen = Image.new("RGBA", S, (0, 0, 0, 0))
    ImageDraw.Draw(sheen).polygon([(150, 706), (420, 222), (540, 222), (270, 706)],
                                  fill=(255, 255, 255, 16))
    sheen_mask = Image.new("L", S, 0)
    ImageDraw.Draw(sheen_mask).rounded_rectangle([150, 222, 874, 706], radius=34, fill=255)
    sheen = Image.composite(sheen, Image.new("RGBA", S, (0, 0, 0, 0)), sheen_mask)
    canvas = Image.alpha_composite(canvas, sheen)

    # 5. warp 残影（两道幽灵光标，渐隐）
    for dx, dy, alpha in [(-330, 14, 45), (-165, 7, 90)]:
        ghost = Image.new("RGBA", S, (0, 0, 0, 0))
        draw_cursor(ghost, 2.2, 548 + dx, 318 + dy, (255, 255, 255, alpha))
        canvas = Image.alpha_composite(canvas, ghost)

    # 6. 主光标：光晕 + 阴影 + 本体
    halo = Image.new("RGBA", S, (0, 0, 0, 0))
    draw_cursor(halo, 2.2 * 1.18, 548 - 8, 318 - 8, (255, 255, 255, 70))
    canvas = Image.alpha_composite(canvas, halo.filter(ImageFilter.GaussianBlur(26)))

    shadow = Image.new("RGBA", S, (0, 0, 0, 0))
    draw_cursor(shadow, 2.2, 548, 318 + 16, (10, 8, 40, 110))
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(20)))

    draw_cursor(canvas, 2.2, 548, 318, (255, 255, 255, 255))

    # 7. 底部 LED 指示灯
    led = Image.new("RGBA", S, (0, 0, 0, 0))
    ImageDraw.Draw(led).ellipse([505, 722, 519, 736], fill=(120, 220, 255, 255))
    canvas = Image.alpha_composite(canvas, led.filter(ImageFilter.GaussianBlur(2)))

    return canvas


def build_menubar(master):
    """菜单栏版本：裁掉周围透明留白，居中到正方形，缩到 72px。
    与 App 图标同一套设计（全彩），在小尺寸下仍能辨认。"""
    crop = master.crop((80, 150, 940, 970))
    sq = Image.new("RGBA", (880, 880), (0, 0, 0, 0))
    sq.alpha_composite(crop, ((880 - crop.width) // 2, (880 - crop.height) // 2))
    return sq.resize((72, 72), Image.LANCZOS)


def pack_icns(master):
    entries = []
    for typ, px in [(b"ic11", 32), (b"ic12", 64), (b"ic07", 128),
                    (b"ic08", 256), (b"ic09", 512), (b"ic10", 1024)]:
        buf = io.BytesIO()
        master.resize((px, px), Image.LANCZOS).save(buf, "PNG")
        data = buf.getvalue()
        entries.append(typ + struct.pack(">I", 8 + len(data)) + data)
    body = b"".join(entries)
    return b"icns" + struct.pack(">I", 8 + len(body)) + body


if __name__ == "__main__":
    master = build_master()
    master.save(OUT_PREVIEW)
    with open(OUT_ICNS, "wb") as f:
        f.write(pack_icns(master))
    build_menubar(master).save(OUT_MENUBAR)
    print("wrote", OUT_ICNS + ",", OUT_MENUBAR, "and", OUT_PREVIEW)
