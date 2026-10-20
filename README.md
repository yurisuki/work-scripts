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
Before installing packages, it enables pacman `Color` and `ILoveCandy` in
`/etc/pacman.conf`, backing up the file when a change is needed. Repeated runs
do not duplicate these options. Config-only installation leaves pacman untouched.
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

Opening one image from a file manager or with `sxiv FILE` loads the other images
in the same directory, sorted by filename, and starts on the selected image.
Running `sxiv` without arguments opens the current directory. Explicit file lists
and commands with options are passed through unchanged. The launcher uses Python 3
from the installed dependencies and `$HOME`, so it works for any user; desktop
launcher paths are filled in by the installer.

Superfile's editor action uses `spf-open`: images set the wallpaper through
`~/.scripts/set-wallpaper.sh`, while other files open in `$EDITOR` (default `nvim`).
The helper and `editor = "spf-open"` configuration are included in deployment.

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
The full installation enables sudo password asterisks with `Defaults pwfeedback`
in `/etc/sudoers.d/99-work-scripts-pwfeedback`. The helper validates the configuration
with `visudo`, backs up an existing managed file, and restores it if validation fails.
Remove that file to undo the installer setting. Tuigreet also shows password
asterisks when configured by the installer. Its styled `S I G N   I N` screen uses
lavender borders, purple accents, and a dark panel. The theme is installed to
`/etc/greetd/tuigreet.toml`, including clock formatting and power-menu commands.
An existing display manager is kept. To explicitly switch it to greetd:

```sh
./install.sh --greetd
```

No session is stopped and no reboot is performed. NetworkManager, Bluetooth, CUPS
and the user audio services are enabled. The quote-download watcher watches your
XDG Downloads folder and moves completed `QT-*.pdf` files into
`~/Dokumenty/Ralakde/1!QUOTES`. There is **no automatic updater**.

GTK 3/4 select the bundled VioletNight dark theme. Both Qt5ct and Qt6ct include
the VioletNight color scheme and select it with the Fusion style. Hyprland session
startup also sets the desktop GTK theme and dark-mode preference for portal consumers.

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

## Power button and lock screen

A short press of the power button opens the session menu in Hyprland. The full
installer enables `power-button-menu.service`, which prevents systemd-logind's
default power-button shutdown during the graphical session, including while
Hyprlock is active. While locked, the menu shortcut is inactive, so a short press
does nothing. Holding the button can still force a hardware shutdown.

After a config-only deployment, enable the service yourself:

```sh
systemctl --user daemon-reload
systemctl --user enable --now power-button-menu.service
```

Hyprlock shows “Caps Lock is on” below the password field only when Caps Lock is
enabled. The indicator checks keyboard LEDs every 250 ms.

## Fingerprint login and lock

Fingerprint support is optional. Without a working reader, Hyprlock and login use
passwords; the installer does not install fingerprint packages or change PAM.
The full installer enables Hyprlock fingerprint support only when fprintd already
reports a reader with enrolled fingerprints for the current user. Config-only
deployment leaves the setting disabled on a new machine. Machine-local
`~/.config/hypr/fingerprint.conf` is preserved on reinstall, including an explicit
disable. Password entry remains available alongside fingerprints in Hyprlock.

First install the driver appropriate for your reader and enroll/verify a finger.
For standard libfprint-supported hardware on Arch, install `fprintd` and
`python-dbus`, then run `fprintd-enroll` and `fprintd-verify`.
Synaptics `06cb:009a` instead requires the alternative `python-validity`,
`open-fprintd` and `fprintd-clients-git` AUR stack; it was verified on this notebook.
Do not install both daemon stacks. Follow the
[driver instructions](https://github.com/uunicorn/python-validity) for initialization
and suspend support. Hardware drivers and services remain machine-specific.

```sh
~/.scripts/setup-fingerprint.py enable         # Enable lock after reader/enrollment checks
~/.scripts/setup-fingerprint.py login          # Opt in to greetd PAM; uses sudo, creates backup
~/.scripts/setup-fingerprint.py disable        # Return lock to password only
~/.scripts/setup-fingerprint.py disable-login  # Remove only the managed greetd PAM rule
```

At greetd login, fingerprint authentication gets one attempt and at most 10 seconds
before falling back to the password. No login service is restarted. Other login
managers are not modified. If a reader later becomes unavailable, password
authentication remains available. Fingerprints are never stored in this repository.
The helper refuses unmanaged fingerprint PAM rules rather than overwriting them.

## ThinkPad keyboard backlight

The full installation enables `restore-keyboard-backlight.service`. It remembers
the current keyboard brightness (including manually switching it off) and restores
it after opening the lid or resuming. It runs only on machines with
`/sys/class/leds/tpacpi::kbd_backlight/brightness`; other machines skip the service.
Dependencies are brightnessctl, UPower, python-dbus and python-gobject.

For an existing installation, run `./install.sh --config-only`, then:

```sh
systemctl --user daemon-reload
systemctl --user enable --now restore-keyboard-backlight.service
```

Install any missing dependencies first. Disable with
`systemctl --user disable --now restore-keyboard-backlight.service`.
Closing and reopening the lid was verified on the ThinkPad.

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
Opening another PDF launches a separate window, keeping the previous PDF open.
Dark mode is applied through `startup_commands` so additional windows use it too.
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
- Bar: `~/.config/waybar/config.jsonc` and `style.css`. Press Super+Ctrl+R after changes.
  Waybar restarts automatically if it exits during the Hyprland session. Startup
  errors are saved to `~/.local/state/waybar/session.log` (or under `$XDG_STATE_HOME`).
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
Work mode shows a brief overlay when enabled or disabled, including while DND is on.
Super+D searches applications, home files/folders, and local Brave bookmarks
and recent history in one launcher.
The search opens with apps only. Typing reveals other sources; clearing the
query hides them again. Results have APP, WINDOW, FILES, BOOKMARKS, HISTORY,
CALC, WEB, or CMD labels. Window results focus an existing window. Arithmetic such
as `125 * 1.21` shows a result that Enter copies; web search runs only when its
result is selected and uses Brave's configured default search engine.
Select CMD to run a background command using your shell, or start with `>` to
show only the command action. No terminal opens; commands run only after
selection. Ctrl+P pins/unpins the selected app. Pinned apps appear
above recently opened apps; both lists are stored locally, not in the repo.
File search skips hidden/build directories and lists names, not file contents.
Brave data is read locally from installed profiles without copying browser data
into the repository. Web results open in Brave; files use their default app.
The bar uses a crossed bell while focus mode is on and a regular bell when off.
The osu! focus command enables focus mode without showing an overlay. Manually
enabled focus mode remains active, and the earlier DND setting is restored when
focus mode fully ends.
Fullscreen focus is limited to video browsers and game windows, so a fullscreen
terminal or editor does not trigger it. The manual, osu!, and automatic requests
are independent.
Notifications held back during focus then appear together as normal popups;
the notification centre stays closed. A temporary user service keeps their
original payloads in memory, preserving icons, actions, and history IDs.
Updated notifications replay only their latest version, and dismissed ones
are skipped. The queue starts with focus mode and stops after replay.

Volume, display brightness, and ThinkPad keyboard backlight use a compact overlay
with adaptive icons. Volume keys and Waybar scrolling unmute before adjusting.
ThinkPad Fn+Space keeps its hardware behavior; the overlay follows backlight changes.
The overlay starts with Hyprland and never adds entries to notification history.
Caps Lock changes show a brief on/off overlay without changing the key's normal
behavior. The XF86AudioMicMute key toggles the default microphone and displays
whether it is muted or live. Num Lock does not show an overlay.
Waybar also shows Caps Lock only while enabled. Its TickTick Inbox indicator
counts incomplete tasks, hides at zero, lists task titles on hover, and opens
TickTick TUI when clicked. It checks every minute using the TUI's existing
sign-in; if unavailable, cached data is labeled in the tooltip. Authentication
and task data stay in the user's existing TUI files and are not bundled here.
After Hyprland login, a quiet TickTick popup summarizes incomplete tasks across
all lists once per session. Empty lists show nothing. The check waits briefly
for startup, retries network failures, and labels cached data if it must fall
back to the TUI's snapshot. It respects DND and uses the same local sign-in.
Audio output changes show the device name with a speaker, headphone, or Bluetooth
icon, including wired headphone/speaker port switches. No output alert plays at login.

Quiet audio feedback covers device connections, maximum volume, screenshots,
power events, and session start/exit. Focus mode silences this feedback while
volume controls keep working. Maximum-volume feedback has a 1.5-second cooldown.
Low-battery alerts trigger at 25% and 10% where system power sensors are available.
Sign-out, shutdown, and restart finish playback before closing the session.
Routine device, charger, screenshot, and reload popups do not remain in SwayNC
history; errors and warnings do. USB, Bluetooth, and charger events use distinct icons.

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
