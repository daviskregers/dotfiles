-- Hyprland config (Lua, 0.55+) — mirrors i3 keybindings from ~/.dotfiles/i3/.config/i3/config
-- Reference: https://wiki.hypr.land/Configuring/  (hyprlang deprecated in favor of Lua since 0.55)

local mainMod = "SUPER"  -- was $mod = Mod4 in i3

-- ------------------------------------------------------------------ monitor / input
-- i3 had GDK_SCALE=2 + Xft.dpi=144; hyprland uses fractional monitor scaling natively.
-- PC desktop monitors: 24–27" 1080p at native scale.
hl.monitor({ output = "DP-2", mode = "preferred", position = "0x0", scale = 1.0 })
hl.monitor({ output = "DP-1", mode = "preferred", position = "1920x0", scale = 1.0 })
-- Default: no scaling for normal-DPI displays.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.0 })
-- Archbook retina internal display (2880x1800): 1.5x fractional scale.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.5 })

hl.config({
  input = {
    kb_layout    = "lv",
    kb_variant   = "apostrophe",
    kb_options   = "",
    kb_rules     = "",
    follow_mouse = 1,
    touchpad     = {
      natural_scroll       = true,
      tap_to_click         = true,
      clickfinger_behavior = true,
      scroll_factor        = 0.5,
    },
    sensitivity  = 0,  -- -1.0..1.0, 0 = no change
  },
  env = {
    { "GTK_THEME", "oldworld" },
    -- Force Electron apps (1Password, etc.) to X11 so they render under XWayland
    -- and avoid broken Wayland fractional-scaling cursor offsets.
    { "ELECTRON_OZONE_PLATFORM_HINT", "x11" },
  },
})

-- ------------------------------------------------------------------ autostart (replaces i3 exec --no-startup-id)
hl.on("hyprland.start", function()
  -- hyprpaper commented until you configure a wallpaper in ~/.config/hypr/hyprpaper.conf
  -- hl.exec_cmd("hyprpaper")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("waybar")
  hl.exec_cmd("hyprshade-ctl init")
  hl.exec_cmd("nm-applet --indicator")
  hl.exec_cmd("wob --config /dev/null")    -- wob IPC socket at $XDG_RUNTIME_DIR/wob.sock
  -- GNOME Online Accounts daemon (gnome-calendar Nextcloud sync)
  hl.exec_cmd("goa-daemon")
end)

-- ------------------------------------------------------------------ programs
local term    = "ghostty"
local menu    = "rofi -show combi"
local fm      = "nautilus"

-- ------------------------------------------------------------------ keybindings
-- start a terminal (i3: $mod+Shift+Return exec ghostty)
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd(term))

-- file manager (i3: $mod+Shift+f exec nautilus)
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd(fm))

-- kill focused window (i3: $mod+Shift+q kill)
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())

-- launcher (i3: $mod+d exec "rofi -show combi")
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))

-- dmenu_run dropped (was X11)

-- ------------------ focus (i3: $mod+h/j/k/l and arrows)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))

-- ------------------ move focused window (i3: $mod+Shift+h/j/k/l and arrows)
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))

-- move workspace between monitors (i3: $mod+Shift+greater/less)
hl.bind(mainMod .. " + SHIFT + greater", hl.dsp.workspace.move({ monitor = "r" }))
hl.bind(mainMod .. " + SHIFT + less",    hl.dsp.workspace.move({ monitor = "l" }))

-- split: i3 had $mod+b split h, $mod+v split v. hyprland dwindle auto-splits;
-- no direct togglesplit dispatcher documented on Dispatchers page. Keys left free (F2c).

-- fullscreen (i3: $mod+f fullscreen toggle)
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))

-- i3 layout stacking / tabbed ($mod+s / $mod+w) — hyprland has no such layouts; keys skipped (F2c).

-- toggle tiling / floating (i3: $mod+Shift+space floating toggle)
hl.bind(mainMod .. " + SHIFT + space", hl.dsp.window.float({ action = "toggle" }))

-- focus tiling vs floating (i3: $mod+space focus mode_toggle) — hyprland has no direct mode_toggle;
-- cycle next window as closest equivalent
hl.bind(mainMod .. " + space", hl.dsp.window.cycle_next())

-- focus parent (i3: $mod+a focus parent) — no hyprland equivalent; mod+a left free.

-- ------------------ workspaces (i3: $mod+1..0 workspace number N)
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

-- move container to workspace (i3: $mod+Shift+1..0)
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- ------------------ session control
-- reload (i3: $mod+Shift+r reload); config auto-reloads on save in hyprland
hl.bind(mainMod .. " + SHIFT + R", function()
  hl.exec_cmd("pkill waybar; sleep 0.3; nohup waybar > /dev/null 2>&1 &")
  hl.dsp.force_renderer_reload()
end)
-- exit (i3: $mod+Shift+e i3-nagbar -> i3-msg exit); wlogout handles the logout menu
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("wlogout"))
-- lock (was xss-lock + i3lock)
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("hyprlock"))

-- ------------------ screenshot (i3: Print -> flameshot, mod+Print -> peek)
-- grim+slurp for capture, swappy for annotation. mod+Print does quick full-output grab.
-- Mac keyboards: no Print key; SUPER+F12 used instead.
hl.bind(mainMod .. " + F12",      hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))
hl.bind(mainMod .. " + SHIFT + F12", hl.dsp.exec_cmd('grim - | swappy -f -'))
hl.bind(mainMod .. " + CTRL + F12", hl.dsp.exec_cmd("hyprshot -m output - | wl-copy"))

-- ------------------ audio (was pactl; now wpctl + pipewire; piped to wob for OSD)
hl.bind("XF86AudioRaiseVolume", function()
  hl.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%+ && wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '/Volume:/{print int($3*100)}' > $XDG_RUNTIME_DIR/wob.sock")
end, { repeating = true })
hl.bind("XF86AudioLowerVolume", function()
  hl.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%- && wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '/Volume:/{print int($3*100)}' > $XDG_RUNTIME_DIR/wob.sock")
end, { repeating = true })
hl.bind("XF86AudioMute",    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && echo 0 > $XDG_RUNTIME_DIR/wob.sock"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))

-- media
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"))

-- brightness (was `change-brightness 5%+ | xob`; xob X11; replaced by wob)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+ && brightnessctl -m info | awk -F, '{print int($NF)}' | tr -d '%' > $XDG_RUNTIME_DIR/wob.sock"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%- && brightnessctl -m info | awk -F, '{print int($NF)}' | tr -d '%' > $XDG_RUNTIME_DIR/wob.sock"))

-- keyboard backlight (macbook smc::kbd_backlight)
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("brightnessctl --device smc::kbd_backlight set 10%+ && brightnessctl --device smc::kbd_backlight -m info | awk -F, '{print int($NF)}' | tr -d '%' > $XDG_RUNTIME_DIR/wob.sock"), { repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl --device smc::kbd_backlight set 10%- && brightnessctl --device smc::kbd_backlight -m info | awk -F, '{print int($NF)}' | tr -d '%' > $XDG_RUNTIME_DIR/wob.sock"), { repeating = true })

-- ------------------ mouse binds (i3 floating_modifier + tiling_drag)
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),    { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(),  { mouse = true })

-- ------------------------------------------------------------------ resize submap (i3 mode "resize")
hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))

hl.define_submap("resize", function()
  hl.bind("h",      hl.dsp.window.resize({ x = -10, y = 0,   relative = true }), { repeating = true })
  hl.bind("j",      hl.dsp.window.resize({ x = 0,   y = 10,  relative = true }), { repeating = true })
  hl.bind("k",      hl.dsp.window.resize({ x = 0,   y = -10, relative = true }), { repeating = true })
  hl.bind("l",      hl.dsp.window.resize({ x = 10,  y = 0,   relative = true }), { repeating = true })
  hl.bind("left",   hl.dsp.window.resize({ x = -10, y = 0,   relative = true }), { repeating = true })
  hl.bind("down",   hl.dsp.window.resize({ x = 0,   y = 10,  relative = true }), { repeating = true })
  hl.bind("up",     hl.dsp.window.resize({ x = 0,   y = -10, relative = true }), { repeating = true })
  hl.bind("right",  hl.dsp.window.resize({ x = 10,  y = 0,   relative = true }), { repeating = true })
  hl.bind("Return", hl.dsp.submap("reset"))
  hl.bind("escape", hl.dsp.submap("reset"))
  hl.bind(mainMod .. " + R", hl.dsp.submap("reset"))
end)

-- ------------------------------------------------------------------ general
hl.config({
  general = {
    gaps_in     = 0,
    gaps_out    = 0,
    border_size = 0,
    layout      = "dwindle",
  },
})

-- ------------------------------------------------------------------ animations
hl.animation({ leaf = "windows",   enabled = true, speed = 2, bezier = "default", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "default", style = "slide" })
hl.animation({ leaf = "fade",      enabled = true, speed = 1.5, bezier = "default" })

-- ------------------------------------------------------------------ decoration / animations / dwindle / master / misc
-- TODO: 0.55 changed the nested-table shape for decoration.shadow, animations.animation.*,
-- dwindle.pseudotile, master.new_is_master — current Lua field names not yet verified.
-- Restoring these belongs in a follow-up slice after checking the 0.55 wiki page shapes.

-- ------------------------------------------------------------------ misc
hl.config({
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
  },
})

-- ------------------------------------------------------------------ xwayland
hl.config({
  xwayland = {
    -- Render XWayland windows at 1.0 scale and upscale them, avoiding cursor
    -- coordinate offset on fractional-scaled monitors.
    force_zero_scaling = true,
  },
})

-- ------------------------------------------------------------------ window rules
hl.window_rule({ match = { class = "^(org.gnome.Calculator)$" }, float = true })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, float = true })
hl.window_rule({ match = { class = "^ pavucontrol$" },           float = true })
hl.window_rule({ match = { class = "^(imv)$" },                  float = true })
hl.window_rule({ match = { class = "^(mpv)$" },                  float = true, center = true })
hl.window_rule({ match = { class = "^(wlogout)$" },             float = true })
hl.window_rule({ match = { class = "^(ssh-askpass)$" },          float = true })
hl.window_rule({ match = { class = "^(1password)$" },          float = true, center = true })

-- EOF