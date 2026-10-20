#!/usr/bin/env bash
# Read keyboard LEDs directly, including while the session is locked.
for led in /sys/class/leds/*::capslock/brightness; do
    if [[ -r "$led" ]] && [[ $(<"$led") == 1 ]]; then
        printf 'Caps Lock is on\n'
        exit 0
    fi
done
