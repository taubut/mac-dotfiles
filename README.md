# mac-dotfiles

macOS rice using AeroSpace + SketchyBar + JankyBorders + Ghostty with dynamic wallpaper-based theming via pywal.

## What's included

| Component | Description |
|-----------|-------------|
| **AeroSpace** | Tiling window manager (i3-style, alt keybindings) |
| **SketchyBar** | Custom status bar with workspace indicators, now playing, battery, wifi, etc. |
| **JankyBorders** | Window border overlay |
| **Ghostty** | Terminal (JetBrains Mono Nerd Font, blur, transparency) |
| **fastfetch** | System info display with themed colors |
| **qutebrowser** | Keyboard-driven browser config |
| **wallpicker** | Swift app to browse/set wallpapers from GitHub repos, auto-catppuccinifies them |
| **pywal integration** | Wallpaper color extraction that themes SketchyBar, JankyBorders, Ghostty, and Fresh editor |

## Install

```bash
git clone https://github.com/taubut/mac-dotfiles.git ~/mac-dotfiles
cd ~/mac-dotfiles
chmod +x install.sh
./install.sh
```

The installer is interactive — it'll ask before each step (brew packages, symlinks, services, etc.).

After install, add `sketchybar` to **System Settings > Privacy & Security > Accessibility** so the now playing widget can read window titles.

## Pywal theming

When you set a wallpaper through wallpicker, it automatically:
1. Extracts colors from the wallpaper using pywal
2. Picks the most vibrant color as the accent
3. Updates SketchyBar, JankyBorders, Ghostty, and Fresh to match

You can also manually run the theming:

```bash
# Run pywal on an image, then apply to all apps
wal -i /path/to/wallpaper.jpg -n -s -t -e -q
wal-sketchybar
```

## Restoring Catppuccin Macchiato

To snap everything back to the default Catppuccin Macchiato Peach theme:

```bash
wal-restore-catppuccin
```

This restores:
- **SketchyBar** — Catppuccin Macchiato color palette with Peach accent
- **JankyBorders** — Peach active borders, Surface1 inactive
- **Ghostty** — Catppuccin Macchiato theme
- **Fresh** — Dracula theme

Note: existing Ghostty windows keep their current theme until reopened. New windows will use the restored theme.

## Key bindings (AeroSpace)

| Keybind | Action |
|---------|--------|
| `alt + 1/2/3` | Switch workspace |
| `alt + shift + 1/2/3` | Move window to workspace |
| `alt + h/j/k/l` | Focus window (left/down/up/right) |
| `alt + shift + h/j/k/l` | Move window |
| `alt + enter` | New Ghostty window |
| `alt + b` | Open qutebrowser |
| `alt + shift + f` | Open Finder |
| `alt + e` | Split opposite (for quadrant tiling) |
| `alt + f` | Toggle fullscreen |
| `alt + shift + space` | Toggle float |
| `ctrl + alt + cmd + g` | Flatten + balance (reset tiling) |

## Scripts

| Script | Location | Description |
|--------|----------|-------------|
| `wal-sketchybar` | `~/.local/bin/` | Reads pywal colors and updates SketchyBar, JankyBorders, Ghostty, Fresh |
| `wal-restore-catppuccin` | `~/.local/bin/` | Restores all apps to Catppuccin Macchiato Peach |
| `catppuccinify` | `~/.local/bin/` | Applies Catppuccin color palette to an image using lutgen |
