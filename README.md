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
TickTick TUI is built with Go from reviewed commit `c1e5a5e1a03ca091a66994fb2f51e82bd3de32d1`
of `raccoon-overlord-dev/ticktick-tui` and installed to `~/.local/bin/ttui`.
Super+U opens it in Kitty; use browser OAuth on first launch. The source build
keeps its default `dev` version, which disables the app's release updater.

In sxiv, the local shortcuts are:

| Shortcut | Action |
| --- | --- |
| `m` / `Shift+m` | Rotate the view 90° clockwise / counterclockwise |
| `,` / `.` | Zoom out / in |
| `Ctrl+0` | Fit the image to the window |
| `Ctrl+c` | Copy the image as PNG to the clipboard |
| `Ctrl+Shift+c` | Copy the absolute image path |
| `o` | Open in GIMP |
| `Shift+Delete` | Move to Trash |

Rotation replaces the default `m` marking shortcut and changes only the view.
Image copying uses the first frame of animated images. In thumbnail mode, clipboard
commands use the first marked image; editor and Trash commands act on all marked
images. `Ctrl+x`, then `d` still sets the wallpaper.
 The local launcher builds a small keymap
library on first use and after source changes, using `cc` from `base-devel` and
the `libx11` headers. File-manager launches use the same launcher. Clipboard
commands use `wl-copy` on Wayland and `xclip` on X11; image conversion uses ImageMagick.

At the next login, choose **Hyprland (uwsm-managed)**. Without a display manager the installer
configures greetd/tuigreet for the next boot. It starts `uwsm start -e -D Hyprland hyprland.desktop`.
The full installation also adds the UWSM TTY login block to `/etc/profile`
(`uwsm check may-start` → `uwsm select` → `exec uwsm start default`).
An existing block is preserved; repeated installation does not duplicate it.
UWSM and libnewt (the session selector) are installed as dependencies.
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

## Bluetooth headphones

Configuration deployment includes a workaround for AULA-G7Pro headphones losing
A2DP after reconnecting. It requires PipeWire and WirePlumber 0.5 or newer:

- `51-aula-g7pro.conf` automatically reconnects A2DP for headset address
  `B6:03:06:00:25:65` (the same headphones on either machine).
- `52-bluetooth-codec-compat.conf` limits **all Bluetooth audio devices for this
  user** to SBC/SBC-XQ, avoiding the AAC negotiation failure observed with this pair.

On another machine, update this checkout and run `./install.sh --config-only`,
then `systemctl --user restart wireplumber` and reconnect the headphones.
Deployment backs up existing files. SBC stereo passed two software reconnect tests;
headphone power-cycle and full reboot behavior have not been verified.
To restore other codecs, remove
`~/.config/wireplumber/wireplumber.conf.d/52-bluetooth-codec-compat.conf` and restart
WirePlumber; also remove its repository copy to keep future deployments from restoring it.

## PDF viewer

Sioyek opens PDFs in standard dark mode without custom theme overrides.
Settings are in `~/.config/sioyek/prefs_user.config`; shortcuts are in
`~/.config/sioyek/keys_user.config`. Restart Sioyek after changing settings.

| Shortcut | Action |
| --- | --- |
| `y` / `Y` | Copy selected text (drag to select; double-click selects a word) |
| `,` / `.` | Zoom out / in |
| `Ctrl+Shift+N` / `Ctrl+Shift+M` | Zoom out / in, matching Kitty directions |
| `w` / `W` | Fit text width without white margins / fit page height |
| `F8` | Toggle dark mode; restore original quote colors |
| `J` / `K` | Next / previous page |
| `Alt+Left` / `Alt+Right` | Back / forward in location history |
| `Ctrl+F`, then `n` / `N` | Search, then next / previous match |
| `b` / `gb` | Add / list document bookmarks |
| `O` | Search recently opened PDFs |
| `Ctrl+B` | Toggle scrollbar |
| `:` | Search all available commands |

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
| Super+Enter / Super+Shift+Enter (also numpad Enter) | Kitty / dropdown terminal |
| Super+D / Super+R                 | Launcher / Superfile                 |
| Super+Shift+W / Super+W           | Brave / nmtui                        |
| Super+V / Super+N                 | Clipboard / notifications            |
| Super+Shift+V                     | Clear clipboard history (confirmation) |
| Super+Ctrl+F                      | Toggle work mode (DND + keep awake)   |
| Super+Ctrl+R                      | Reload Hyprland and refresh Waybar    |
| Super+T                           | Open the text template picker         |
| Super+U                           | Open TickTick TUI in Kitty            |
| Print / Super+S                   | Copy screenshot selection to clipboard |
| Super+Print / Super+Shift+S       | Annotate screenshot in Swappy         |
| Alt+Print / Super+Alt+S           | Click a window to copy its screenshot |
| Super+Alt+Print / Super+Alt+Shift+S | Click a window to annotate in Swappy |
| Super+Shift+E                     | Search emoji and copy to clipboard   |
| Super+H/J/K/L or arrows           | Focus left/down/up/right             |
| Super+Shift+H/J/K/L or arrows     | Move tiled window / floating by 30 px |
| Super+Alt+H/J/K/L or arrows       | Resize window                        |
| Super+Ctrl+H/K or ←/↑             | Decrease inner and outer gaps by 2 px |
| Super+Ctrl+J/L or ↓/→             | Increase inner and outer gaps by 2 px |
| Super+Shift+G                     | Reset gaps to defaults (5 / 12 px)    |
| Super+number / Super+Shift+number | Workspace / move window to workspace |
| Super+X / Super+F / Super+Q       | Lock / fullscreen / close            |
| Super+G                           | Make focused window largest          |
| Super+C / Super+Shift+Escape      | Calculator / gotop                   |
| Super+Escape                      | Session menu                         |
| Super+Y                           | Open the last downloaded quote       |
| Super+B                           | Bluetooth settings (bluetui)          |
| Super+Shift+B                     | Toggle bar                           |

Workspaces 1–5 stay visible; 6–10 appear when selected or occupied. Click audio for
Wiremix and the clock for Calcure. Clipboard is available through its shortcut; Shift+Delete in the picker deletes the selected entry.
Work mode shows a brief notification when enabled or disabled, including while DND is on.

In Sioyek, `p` opens the current PDF in a new Brave window. `u` crops the current
DHL label to 4×6 inches and opens the result in Brave. Cropped PDFs are kept in
the runtime directory so Brave can continue reading them.
Turning it off restores the previous DND setting.
It prevents idle locking and screen blanking, while manual locking and suspend remain available.
Screenshots freeze the screen with hyprpicker before selection. Copy mode writes only
to the clipboard; editor mode saves to Pictures/Screenshots only on Ctrl+S.
Cancelling selection removes the frozen overlay and leaves the clipboard unchanged.
Kitty: `Ctrl+Shift+O` toggles full opacity and the configured 85% opacity.
Neovim: `<leader>q` quits, `<leader>e` opens Neo-tree, `<leader>de` shows diagnostics,
and `<leader>dq` fills the diagnostic location list.

Emoji picker: `~/.scripts/rofi-emoji.py` (or `~/.scripts/hypr-menu.sh emoji`).
Search English names or categories, press Enter to copy, then Ctrl+V to paste.
Escape cancels without changing the clipboard. All Unicode Emoji 17.0 entries,
including skin tones, flags and ZWJ sequences, are bundled for offline use in
`.local/share/emoji/emoji-test.txt`; newer glyphs depend on your emoji font.
Source: https://unicode.org/Public/17.0.0/emoji/emoji-test.txt (Unicode license
included alongside the data). Dependencies: Python 3, rofi, wl-clipboard and
noto-fonts-emoji, already included in the installer.

## Work-specific setup

Applications installed include OnlyOffice, Brave, Zapzap, TickTick TUI, Superfile,
gotop, Qalculate, Xournal++, VLC and the Python dependencies for work scripts.
Neovim installs its pinned plugins on first launch (internet required); configured
language servers and formatters are supplied by the installer.

Zoho WorkDrive uses its [vendor installer](https://www.zoho.com/workdrive/desktop-sync.html)
and requires your account. Sign in and sync your files .

## Backups and checks

Each configuration deployment creates `~/.local/state/work-scripts/install-backup.*`
with `manifest.json` and `files/`. To undo, restore `replaced`/`removed` files from
that backup and remove only files marked `created`. Do not delete shared directories.
Profile changes are backed up in `/etc/profile.backup.*`.
Login manager changes are backed up separately in `/etc/greetd/config.toml.backup.*`.
Symlinked parent directories are rejected before deployment; existing individual
file symlinks are backed up and replaced without writing through them.

```sh
hyprctl configerrors
python install/check-config.py  # Read-only comparison with your local files
```

The comparison exits with status 1 when managed files differ. Deployment also lists these
differences before replacing files, and keeps its existing backups and personal-setting exclusions.

Package downloads and AUR builds can change or fail independently of this repo;
installation stops on errors, and the same command can be rerun after fixing them.

Clipboard image entries show cached 64 px previews in Rofi. Original image data is
copied on Enter; Shift+Delete removes the selected entry and its preview. Thumbnails
are kept only in the session runtime directory.

Enter the place name normally, including Czech diacritics. Both the bar and forecast
normalize the service query automatically (lowercase, without diacritics), while
preserving the original display name. No separate coordinates are needed. A failed
forecast request shows the last successful forecast for the same query and units,
with its age and an offline label.

## Text templates

Super+T opens rtemplate with Violet Night styling, filename search and text previews.
Enter copies the selected template, Alt+E edits it in Neovim, Alt+O opens the folder
in Superfile, and Escape cancels without changing the clipboard. Existing templates
stay in `~/Dokumenty/Ralakde/Zoho WorkDrive (Ralakde)/My Folders/rtemplate list`.
Subfolders are shown with relative paths so duplicate filenames remain distinct.
The picker expands `$DATE`, `$TIME`, `$DATETIME`, and `$CLIPBOARD`, plus their
`${NAME}` forms. Clipboard text is captured before the picker opens. Newlines and
literal backslashes are preserved; template contents are never executed as code.

Screenshots: `Print` or `Super+S` copies a selected area without saving a file. `Super+Print` or `Super+Shift+S`
opens the selection in Swappy with its tool panel visible. Draw arrows, text or
shapes; toggle transparency (`T`) for highlighting. `Ctrl+C` copies the edited
image and closes the editor; `Ctrl+S` explicitly saves to the Pictures/Screenshots
directory and closes it. Closing without either action discards the screenshot.
Temporary captures are removed when the command finishes.

For window screenshots, use `Alt+Print` or `Super+Alt+S` and click a window
on a visible workspace. `Super+Alt+Print` or `Super+Alt+Shift+S` opens that
selection in Swappy. Escape cancels the selection. These capture the screen
rectangle occupied by the window, including anything overlapping it.

HyprMod is installed from AUR by the installer. Hyprland loads its settings with
`require("hyprland-gui")`; the installer preserves existing
`~/.config/hypr/hyprland-gui.lua` settings and supplies an empty starter file
on a fresh installation.

Screenshot dependencies include `hyprpicker` for frozen selection in both area
and window modes. The overlay is removed before opening Swappy and on cancellation
or capture failure. Existing Print and Super+S shortcuts are unchanged.
