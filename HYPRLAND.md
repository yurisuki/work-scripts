# Violet Night · Hyprland

An optional desktop alongside Plasma, using the existing Violet Night palette:
`#171020` background, `#241a30` surfaces, `#ede3f5` text, `#cf5aff` purple and
`#a69bff` lavender accents. Files mirror their locations under your home directory,
just like the existing dotfiles. This branch is local; nothing is pushed.

## Components

| Purpose | Application |
| --- | --- |
| Compositor | Hyprland 0.55+ with Lua configuration |
| Status bar | Waybar: workspaces, clock, tray, network, volume, brightness, clipboard, notifications |
| Notifications | SwayNC, including history, do-not-disturb, volume and media controls |
| Terminal | Kitty with Violet Night colors and JetBrains Mono Nerd Font |
| Launcher / clipboard picker | Rofi + cliphist + wl-clipboard |
| Network settings / Wi-Fi tray | nm-connection-editor / nm-applet |
| Audio | Existing PipeWire / WirePlumber, with pavucontrol |
| Brightness | brightnessctl for backlights; ddcutil for DDC/CI monitors |
| Lock / idle | Hyprlock / Hypridle |
| Authentication prompts | hyprpolkitagent |
| GTK / Qt appearance | Local VioletNight GTK theme / qt5ct + qt6ct palettes |
| Screen sharing / file dialogs | Hyprland and GTK desktop portals |
| Login manager | Existing SDDM, unchanged |

## Installation

Run from this checkout, as your normal user, on an up-to-date Arch/Manjaro system:

```sh
./.scripts/install-hyprland.sh
```

The installer uses your configured distro repositories, not Arch repositories on
Manjaro. It does not refresh package databases separately, run a distribution
upgrade, enable/disable services, change SDDM, remove Plasma, reboot, or change the
currently running session. NetworkManager and PipeWire are expected to be active
(as they already are on this machine). On a fresh Arch installation, configure
those services as part of the base system setup.

Separate phases are available:

```sh
./.scripts/install-hyprland.sh --packages-only
./.scripts/install-hyprland.sh --config-only
```

The full `postinstall.sh` also offers this desktop during dotfile setup.
At your next logout, select **Hyprland** in the existing SDDM session selector.
Choose **Plasma** to return to the previous desktop. No logout is performed for you.

Existing files are copied to `~/.local/state/work-scripts/hyprland-backup.*` before
replacement. Each backup includes `manifest.tsv` listing newly created and replaced
files and `files/` containing the originals. To undo the dotfiles, log into Plasma,
restore entries marked `replaced` from that backup, and remove only entries marked
`created`. Installed packages can remain; they do not launch automatically in Plasma.
Do not delete whole shared configuration directories.

## Using the desktop

- Click the Arch icon for applications; click a workspace number to switch.
- Click network status to edit connections; use the network tray icon for Wi-Fi.
- Click volume for the mixer, scroll to adjust, right-click to mute.
- Click brightness for presets or scroll for 5% steps.
- Click clipboard for history; right-click to clear it with confirmation.
- Click the bell for notification history; right-click for do-not-disturb.
- Click power for lock, suspend, logout, restart, and shutdown.

Clipboard text and images are saved locally by cliphist. Clear the history from
the bar when needed. Empty clipboard selections and cancelled menus do nothing.

Starter shortcuts are isolated in `~/.config/hypr/keybinds.lua` for later refinement:

| Shortcut | Action |
| --- | --- |
| Super + Enter | Kitty |
| Super + Shift + W | Brave |
| Super + W | Network connection editor |
| Super + D | Application launcher |
| Super + V | Clipboard history |
| Super + N | Notification panel |
| Super + L | Lock |
| Super + Escape | Session menu |
| Super + Q | Close window |
| Super + arrow | Focus window |
| Super + physical number-row key | Workspace 1–10 |
| Super + Shift + physical number-row key | Move window to workspace |
| Super + left/right mouse drag | Move/resize |

The Czech keyboard layout is retained. Add monitor scale, position, or keyboard
changes in `~/.config/hypr/local.lua`; the installer preserves that optional file.
Locking occurs after 10 minutes idle; displays turn off after 11 minutes and wake
on activity. Sleep requests are coordinated with Hypridle's lock inhibitor. There
is no automatic suspend. Unlocking uses the normal system password through PAM.

## Brightness

This machine has external monitors, not a laptop backlight. DDC/CI must be enabled
in the monitor's own menu. The installer loads `i2c-dev`; ddcutil's packaged rules
handle future boots and device permissions. Unsupported monitors show `—` with an
explanation instead of a false percentage. Software dimming is not applied.

The first DDC monitor is controlled by default. To choose another, inspect
`ddcutil detect` and create `~/.config/hypr/brightness.json`, for example:

```json
{"ddc_display": 2}
```

## Theme scope and checks

Hyprland selects the GTK and Qt themes through its own environment. Plasma's
shared GTK settings, KDE global theme, SDDM theme, and the existing Rofi config are
not overwritten. The Hyprland menus explicitly load `rofi/violet-night.rasi`.
Some applications (including those with their own web or libadwaita themes) may
retain parts of their own appearance. Browser page content is not recolored.

Useful diagnostics after installation:

```sh
Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
hyprctl configerrors
~/.scripts/hypr-brightness.sh status
```

References: [Hyprland configuration](https://wiki.hypr.land/Configuring/Start/),
[Waybar](https://github.com/Alexays/Waybar/wiki),
[SwayNC](https://github.com/ErikReider/SwayNotificationCenter),
[Hyprlock](https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/),
[Hypridle](https://wiki.hypr.land/Hypr-Ecosystem/hypridle/).
