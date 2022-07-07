local wezterm = require 'wezterm';

return {
  color_scheme = "Afterglow",
  colors = {
    background = "#282828",
  },
  font_size = 10.0,
  hide_tab_bar_if_only_one_tab = true,
  window_background_opacity = 1.0,
  font = wezterm.font("FiraCode Nerd Font Mono"),
  send_composed_key_when_left_alt_is_pressed=true,
  send_composed_key_when_right_alt_is_pressed=false,
  use_ime=true,
}
