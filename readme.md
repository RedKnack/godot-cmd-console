# Cmd Console (Godot 4 Editor Plugin)

**Cmd Console** is a lightweight **Godot 4 editor plugin** by **RedKnack Interactive**
that adds a small console dock/panel for editor-time commands and logging.

- Godot: tested with **4.5.1**
- Language: **GDScript**
- Install path: `addons/cmd_console/`

---

## Features

- Dockable console panel inside the editor
- Command input + output/log view
- No external dependencies

---

## Installation

### Godot Asset Library
1. In Godot: **AssetLib**
2. Search for **Cmd Console**
3. Install
4. Go to **Project → Project Settings → Plugins**
5. Enable **Cmd Console**

### Manual
Copy `addons/cmd_console/` into your project and enable the plugin:
**Project → Project Settings → Plugins**

---

## Usage

1. Enable the plugin.
2. Open the console dock/panel in the editor.
3. Enter commands and review output in the log area.

To adapt commands / behavior, check:
- `addons/cmd_console/plugin.gd`
- `addons/cmd_console/console_panel.gd`

---

## License

### Plugin code
MIT License — see `LICENSE`.

### Third-party assets (Font)
This repository includes a font (`Unifontexmono-lxY45.ttf`) licensed under **GPL-2.0**.
See `THIRD_PARTY_NOTICES.md` and `LICENSES/GPL-2.0.txt`.
