# Violet Night bar

- Network left-click and Super+W: open or focus the same centered nmtui terminal.
- Audio left-click: open or focus a centered wiremix terminal (Arch package: wiremix);
  wheel changes volume. Repeated clicks focus the existing window.
- Brightness: wheel changes by 5%; requests are coalesced by a single worker.
  The slider has been removed. DDC/CI hardware still has its own write latency.
- Clock: system locale from /etc/locale.conf, optionally overridden by
  ~/.config/locale.conf, rendered by ~/.scripts/bar-start.py at login.
  Hover for the built-in calendar; click for Calcure in Kitty. Install Calcure with `uv tool install calcure` or `yay -S calcure`.
- Laptop battery: automatically hidden when absent. Bluetooth battery appears
  only when a connected device reports a percentage through BlueZ.
- Network, audio and brightness share one status group.
- Super+Ctrl+R reloads Hyprland and refreshes Waybar configuration, locale and CSS.
- Workspaces: 1–5 always visible; 6–10 appear only when selected or occupied.
  Mouse wheel cycles persistent and existing workspaces.
- Workspace state is cached by one event-socket listener launched alongside Waybar;
  widgets read the cache only at startup and after workspace/window events.
- Clipboard: Super+V; Shift+Delete removes a selected item; Super+Shift+V clears history.
- Work mode: Super+Ctrl+F enables DND and prevents idle locking/blanking.
  A brief notification confirms each change; no separate bar widget is shown.
  Turning it off restores the earlier DND state.

## Weather

Left-click the weather icon for the full colored wttr.in report, including the
three-day forecast, in a floating terminal below the bar.
Press Enter to close it. Right-click to edit ~/.config/waybar/weather.json:

```json
{"location": "Praha", "units": "m"}
```

Use a city, address supported by wttr.in, or latitude,longitude. Empty location
means no network request. `m` selects Celsius, `u` Fahrenheit. The configured
bar reading is fetched every 30 minutes at most, with a shared cache across
monitors. Opening the forecast makes a separate request to wttr.in for the configured location. A failed request keeps the previous reading marked offline.

Restart the bar after locale changes with ~/.scripts/bar-start.py (first stop the
existing Waybar), or log in again. Dependencies: waybar, kitty, networkmanager,
wiremix, calcure, bluez, brightnessctl, ddcutil, python.

Clipboard image entries show cached 64 px previews in Rofi. Original image data is
copied on Enter; Shift+Delete removes the selected entry and its preview. Thumbnails
are kept only in the session runtime directory.

Enter the place name normally, including Czech diacritics. Both the bar and forecast
normalize the service query automatically (lowercase, without diacritics), while
preserving the original display name. No separate coordinates are needed. A failed
forecast request shows the last successful forecast for the same query and units,
with its age and an offline label.
