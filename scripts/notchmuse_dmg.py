application = defines.get("application")
background = defines.get("background")
guide = defines.get("guide")

files = [application, guide]
symlinks = {"Applications": "/Applications"}
icon_locations = {
    "NotchMuse.app": (150, 270),
    "Applications": (618, 270),
    "安装说明.txt": (90, 90),
}
window_rect = ((100, 100), (768, 512))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 96
text_size = 13
format = "UDZO"
