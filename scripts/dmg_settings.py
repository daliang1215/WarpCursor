# dmgbuild 配置（由 make_dmg.sh 调用）。
# 路径通过 -D 传入：app / background / icon。布局参数与
# scripts/generate_dmg_background.py 的画布几何保持一致。
app = defines.get("app", "build/WarpCursor.app")
background_file = defines.get("background", "Resources/dmg-background.png")
icon_file = defines.get("icon", "build/WarpCursor.app/Contents/Resources/AppIcon.icns")

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = icon_file
background = background_file

window_rect = ((120, 120), (660, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 128.0
text_size = 13.0
icon_locations = {
    "WarpCursor.app": (185, 175),
    "Applications": (475, 175),
}
