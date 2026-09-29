#!/usr/bin/env python3
"""Display wttr.in's full colored forecast in a floating terminal."""
import json
from pathlib import Path
import subprocess
from urllib.parse import quote

print('Načítám předpověď z wttr.in…', flush=True)
try:
    settings = json.loads((Path.home() / '.config/waybar/weather.json').read_text())
    location = settings.get('location', '').strip()
    units = settings.get('units', 'm')
    if not location:
        raise ValueError('Nastav lokalitu pravým kliknutím na počasí ve Waybaru.')
    if units not in ('m', 'u'):
        raise ValueError('Jednotky musí být m nebo u.')
    url = 'https://wttr.in/' + quote(location, safe='') + '?' + units + '&lang=cs'
    response = subprocess.run(
        ['curl', '--fail', '--silent', '--show-error', '--max-time', '25',
         '--user-agent', 'curl', url],
        capture_output=True, text=True, check=True, timeout=30,
    )
    print('\033[2J\033[H' + response.stdout, end='', flush=True)
except (OSError, ValueError, subprocess.SubprocessError) as error:
    print(f'Předpověď se nepodařilo načíst: {error}')
try:
    input('\nEnter — zavřít ')
except (EOFError, KeyboardInterrupt):
    pass
