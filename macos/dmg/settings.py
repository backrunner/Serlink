"""Finder layout shared by development and Developer ID disk images."""

import os

app = defines["app"]
app_name = os.path.basename(app)
files = [app]
format = "UDZO"
filesystem = "HFS+"
background = defines["background"]
window_rect = ((180, 140), (720, 480))
default_view = "icon-view"
icon_locations = {app_name: (360, 236)}
icon_size = 112
text_size = 13
# SetFile extension flags add FinderInfo to the signed app root, which causes
# codesign --strict to reject the installed copy. Leave its metadata untouched.
hide_extensions = []
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
include_icon_view_settings = True
include_list_view_settings = False
arrange_by = None
