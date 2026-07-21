# Theme sync

Terminal/launchbar/UI themes mirror the neovim colorscheme so everything matches.

- **Theme:** [oldworld.nvim](https://github.com/dgox16/oldworld.nvim)
- **Active variant:** `oled` — set in `nvim/.config/nvim/lua/plugins/colorscheme.lua:5`
- **Palette source of truth:** `~/.local/share/nvim/site/pack/core/opt/oldworld.nvim/lua/oldworld/variants.lua` (3 variants: `default`, `cooler`, `oled`)

## oled palette

| role       | hex      | note                         |
|------------|----------|------------------------------|
| bg         | `#000000` | `bg`, `bg_dark`              |
| bg-alt     | `#161617` | `black` (panel/selection bg) |
| fg         | `#c9c7cd` |                              |
| fg-alt     | `#9f9ca6` | `subtext2`                   |
| red        | `#ea83a5` |                              |
| orange     | `#f5a191` |                              |
| yellow     | `#e6b99d` |                              |
| green      | `#90b99f` | active state                 |
| cyan       | `#85b5ba` |                              |
| blue       | `#92a2d5` |                              |
| purple     | `#aca1cf` | accent (borders, prompts)    |
| magenta    | `#e29eca` |                              |
| gray0..5   | `#000000` · `#18181a` · `#1b1b1c` · `#2a2a2c` · `#313134` · `#444448` | |

For other variants, read `variants.lua` directly — this table only carries `oled` (the active one) to avoid drift.

## Synced tools

| tool  | file                                           |
|-------|------------------------------------------------|
| rofi  | `rofi/.config/rofi/oldworld-oled.rasi`         |

## When the variant changes

1. Update `colorscheme.lua` (nvim side).
2. Update the palette table above to the new variant's hex values (or it lies).
3. Update each synced tool's theme file — rofi: replace the `rgb` block at the top of `oldworld-oled.rasi`.