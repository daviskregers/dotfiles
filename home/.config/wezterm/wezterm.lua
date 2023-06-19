local wezterm = require 'wezterm';

local arch = io.popen('uname -s', 'r'):read('*l')

local font_size = 10.0
if arch == 'Darwin' then
    font_size = 12.0
end

return {
    color_scheme = "Afterglow",
    colors = {
        background = "#282828",
    },
    font_size = font_size,
    hide_tab_bar_if_only_one_tab = true,
    window_background_opacity = 0.9,
    font = wezterm.font("FiraCode Nerd Font Mono"),
    send_composed_key_when_left_alt_is_pressed = true,
    send_composed_key_when_right_alt_is_pressed = false,
    use_ime = true,
    enable_scroll_bar = false,
    window_padding = {
        left = 25,
        right = 25,
        top = 25,
        bottom = 25,
    },
}
