# quickshell

A small, self-contained [Quickshell](https://quickshell.org/) bar for Hyprland — one file, no build step.

## Features

- **left** — workspaces (filled = has windows, accent = current, red = urgent)
- **center** — focused window title
- **right** — network menu, volume, battery %, date + time
- **Super+A** — app launcher: type to filter, Up/Down to pick, Enter to launch, Esc or a click outside to close
- **wifi menu** — click the wifi icon; click an open/known network to connect, or type the password for a new secured one; the little switch toggles wifi

Everything is in one file on purpose, so you can copy/back it up easily.

## Install

```bash
mkdir -p ~/.config/quickshell
cp shell.qml ~/.config/quickshell/shell.qml
```

Run it with:

```bash
qs
```

## Autostart from Hyprland

In your `hyprland.lua`:

```lua
hl.on("hyprland.start", function()
  hl.exec_cmd("qs -d -n")
end)
```

## Requirements

- [Quickshell](https://quickshell.org/)
- Hyprland
