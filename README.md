# Violet Night + work scripts

Personal Hyprland desktop and Ralakde work tools for **Arch Linux / Manjaro x86_64**.
Requires an installed system, internet connection, a normal user with sudo access,
and a working systemd user session. This is not an operating-system installer.

## Install

Log in as your normal user (TTY or desktop), then:

```sh
sudo pacman -Syu --needed git
git clone https://github.com/yurisuki/work-scripts.git
cd work-scripts
./install.sh
```

The installer installs desktop/work dependencies from your configured repositories,
then asks yay to install the AUR applications. Review package/build prompts normally.
Calcure 3.4 is installed in an isolated user environment with uv. Hyprland must be
0.55 or newer; the installer checks this before deploying the Lua configuration.

At the next login, choose **Hyprland**. Without a display manager the installer
configures greetd/tuigreet for the next boot. It starts **start-hyprland**.
An existing display manager is kept. To explicitly switch it to greetd:

```sh
./install.sh --greetd
```

No session is stopped and no reboot is performed. NetworkManager, Bluetooth, CUPS
and the user audio services are enabled. The quote-download watcher watches your
XDG Downloads folder and moves completed `QT-*.pdf` files into
`~/Dokumenty/Ralakde/1!QUOTES`. There is **no automatic updater**.

## Other modes

```sh
./install.sh --config-only    # Dotfiles and scripts only; requires Python 3
./install.sh --packages-only  # Dependencies only
./install.sh --no-upgrade     # Only if the system/databases are already up to date
```

`./postinstall.sh` accepts the same options. Rerunning is supported: modified files
are backed up before replacement. Personal `local.lua`, brightness selection,
weather location, wallpaper selection and existing work documents are preserved.
The repository uses automatic monitor detection; no desktop-specific DP-1 mode is
installed on your notebook. Kitty uses Zsh without changing your login shell.

## Personal settings

- Monitor, scale, keyboard overrides: `~/.config/hypr/local.lua`.
- Weather: click its bar icon, edit `~/.config/waybar/weather.json`, set `location`
  to your town/address or coordinates. Empty location disables requests. Data comes
  from wttr.in, cached for 30 minutes; the location is sent to that service.
- Bar: `~/.config/waybar/config.jsonc` and `style.css`. Restart Waybar after changes
  (`pkill -x waybar; ~/.scripts/bar-start.py`) from a terminal inside Hyprland.
- Clock language: follows `/etc/locale.conf`, with optional user overrides in
  `~/.config/locale.conf`.
- External-monitor brightness: enable DDC/CI in the monitor menu. Optional
  `~/.config/hypr/brightness.json`: `{"ddc_display": 2}`. Notebook backlight is
  detected automatically. Wheel events are combined; DDC hardware still has latency.
- Battery widgets are hidden when absent. Bluetooth battery needs a device/BlueZ
  connection that reports a battery percentage.

## Shortcuts

| Shortcut                          | Action                               |
| --------------------------------- | ------------------------------------ |
| Super+Enter / Super+Shift+Enter   | Kitty / dropdown terminal            |
| Super+D / Super+R                 | Launcher / Superfile                 |
| Super+Shift+W / Super+W           | Brave / nmtui                        |
| Super+V / Super+N                 | Clipboard / notifications            |
| Super+H/J/K/L or arrows           | Focus left/down/up/right             |
| Super+Shift+H/J/K/L or arrows     | Move window                          |
| Super+Alt+H/J/K/L or arrows       | Resize window                        |
| Super+number / Super+Shift+number | Workspace / move window to workspace |
| Super+X / Super+F / Super+Q       | Lock / fullscreen / close            |
| Super+G                           | Make focused window largest          |
| Super+C / Super+Shift+Escape      | Calculator / gotop                   |
| Super+Escape                      | Session menu                         |
| Super+B                           | Toggle bar                           |

Workspaces 1–5 stay visible; 6–10 appear when selected or occupied. Click audio for
Wiremix and the clock for Calcure. Clipboard is available through its shortcut.

## Work-specific setup

Applications installed include OnlyOffice, Brave, Zapzap, TickTick, Superfile,
gotop, Qalculate, Xournal++, VLC and the Python dependencies for work scripts.
Neovim installs its pinned plugins on first launch (internet required); configured
language servers and formatters are supplied by the installer.

Zoho WorkDrive uses its [vendor installer](https://www.zoho.com/workdrive/desktop-sync.html)
and requires your account. Sign in and sync your files before using Stock Search;
its launcher expects `~/Dokumenty/Ralakde/Zoho WorkDrive (Ralakde)/My Folders/Search stock tool/search_stock_V1_PRO.py`.
Printer hardware/queues are not guessed: configure CUPS, then use `GK420d` or set
`LABEL_PRINTER` for the label printing script. No credentials or printer settings
are included.

## Backups and checks

Each configuration deployment creates `~/.local/state/work-scripts/install-backup.*`
with `manifest.json` and `files/`. To undo, restore `replaced`/`removed` files from
that backup and remove only files marked `created`. Do not delete shared directories.
Login manager changes are backed up separately in `/etc/greetd/config.toml.backup.*`.
Symlinked parent directories are rejected before deployment; existing individual
file symlinks are backed up and replaced without writing through them.

```sh
python3 -m unittest discover -s tests -v
hyprctl configerrors
```

Package downloads and AUR builds can change or fail independently of this repo;
installation stops on errors, and the same command can be rerun after fixing them.
