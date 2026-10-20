# Notifications

Desktop notifications and quiet audio feedback for device connections,
maximum volume, low battery, screenshots, charger connections, and session exit.

- Focus mode silences all audio feedback without disabling volume controls.
- Maximum-volume feedback has a 1.5-second cooldown.
- Low-battery alerts trigger at 25% and 10% while discharging.
- Screenshot feedback plays only after a successful capture.
- Session-start feedback plays once when the Hyprland session starts.
- Sign-out, shutdown, and restart wait briefly for playback to finish.
- USB, Bluetooth, and charger notifications use distinct connection-state icons.
- Charger disconnection is silent.

Power events require battery or adapter sensors exposed by the system.
