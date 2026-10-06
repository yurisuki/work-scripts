#!/usr/bin/env python3
"""Display wttr.in's colored forecast, retaining the last successful report."""
import json
from pathlib import Path
import time
from urllib.parse import quote
from urllib.request import Request, urlopen

from weather_common import error_message, read_settings


def main():
    print('Načítám předpověď z wttr.in…', flush=True)
    settings = None
    cache = Path.home() / '.cache/waybar/forecast.json'
    try:
        settings = read_settings()
        if not settings['location']:
            raise ValueError('Nastav lokalitu pravým kliknutím na počasí ve Waybaru.')
        url = 'https://wttr.in/' + quote(settings['query'], safe='') + '?' + settings['units'] + '&lang=cs'
        with urlopen(Request(url, headers={'User-Agent': 'curl'}), timeout=25) as response:
            forecast = response.read().decode('utf-8')
        if not forecast.strip() or 'Unknown location' in forecast or 'location not found' in forecast:
            raise ValueError('wttr.in nerozpoznalo lokalitu. Zkus upřesnit název místa v weather.json.')
        if forecast.startswith('Předpověď počasí pro:'):
            forecast = 'Předpověď počasí pro: ' + settings['location'] + '\n' + forecast.partition('\n')[2]
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(json.dumps({**settings, 'forecast': forecast, 'fetched': time.time()}))
        print('\033[2J\033[H' + forecast, end='', flush=True)
    except (OSError, ValueError) as error:
        message = error_message(error)
        try:
            saved = json.loads(cache.read_text())
            if settings is None or saved['query'] != settings['query'] or saved['units'] != settings['units']:
                raise ValueError('No matching cached forecast')
            stamp = time.strftime('%d.%m. %H:%M', time.localtime(saved['fetched']))
            print('\033[2J\033[H' + saved['forecast'], end='')
            print(f'\n⚠ Offline — poslední předpověď z {stamp}.\n{message}')
        except (OSError, ValueError, KeyError):
            print(f'Předpověď se nepodařilo načíst: {message}')
    try:
        input('\nEnter — zavřít ')
    except (EOFError, KeyboardInterrupt):
        pass


if __name__ == '__main__':
    main()
