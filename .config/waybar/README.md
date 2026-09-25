# Violet Night bar

- Network icon and Super+W: nmtui in Kitty.
- Audio click: wiremix (Arch package: wiremix); wheel changes volume.
- Brightness: wheel changes by 5%; requests are coalesced by a single worker.
  The slider has been removed. DDC/CI hardware still has its own write latency.
- Clock: system locale from /etc/locale.conf, optionally overridden by
  ~/.config/locale.conf, rendered by ~/.scripts/bar-start.py at login.
  Hover for the built-in calendar; click for Calcure in Kitty. Install Calcure with `uv tool install calcure` or `yay -S calcure`.
- Laptop battery: automatically hidden when absent. Bluetooth battery appears
  only when a connected device reports a percentage through BlueZ.
- Workspaces: 1–5 always visible; 6–10 appear only when selected or occupied.
  Mouse wheel cycles persistent and existing workspaces.
- Clipboard remains available with Super+V.

## Weather

Click the weather icon to edit ~/.config/waybar/weather.json:

```json
{"location": "Praha", "units": "m"}
```

Use a city, address supported by wttr.in, or latitude,longitude. Empty location
means no network request. `m` selects Celsius, `u` Fahrenheit. The configured
location is sent to wttr.in every 30 minutes at most, with a shared cache across
monitors. A failed request keeps the previous reading marked offline.

Restart the bar after locale changes with ~/.scripts/bar-start.py (first stop the
existing Waybar), or log in again. Dependencies: waybar, kitty, networkmanager,
wiremix, calcure, bluez, brightnessctl, ddcutil, python.
