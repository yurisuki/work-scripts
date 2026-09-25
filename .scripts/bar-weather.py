#!/usr/bin/env python3
"""wttr.in weather; Waybar schedules a request every 30 minutes."""
import fcntl
import time
import html
import json
from pathlib import Path
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen

config = Path.home() / '.config/waybar/weather.json'
cache = Path.home() / '.cache/waybar/weather.json'
cache.parent.mkdir(parents=True, exist_ok=True)
lock = (cache.parent / 'weather.lock').open('w')
fcntl.flock(lock, fcntl.LOCK_EX)
try:
    settings = json.loads(config.read_text())
    location = settings.get('location', '').strip()
    if not location:
        result = {'text': '☁ ⚙', 'tooltip': 'Kliknutím nastavte location v weather.json (např. Praha).'}
    else:
        units = settings.get('units', 'm')
        if units not in ('m', 'u'):
            raise ValueError('units must be m or u')
        try:
            saved = json.loads(cache.read_text())
            if saved['location'] == location and saved['units'] == units and time.time() - saved.get('fetched', 0) < 1800:
                print(json.dumps(saved['result'], ensure_ascii=False))
                raise SystemExit(0)
        except (OSError, ValueError, KeyError):
            pass
        url = 'https://wttr.in/' + quote(location, safe='') + '?' + urlencode({'format':'j1', units:''})
        with urlopen(Request(url, headers={'User-Agent':'VioletNight-Waybar/1.0'}), timeout=12) as response:
            current = json.load(response)['current_condition'][0]
        temperature = current['temp_F' if units == 'u' else 'temp_C']
        description = current['weatherDesc'][0]['value']
        result = {'text': f'☁ {temperature}°' + ('F' if units == 'u' else 'C'), 'tooltip': html.escape(f'{location}: {description}\nHumidity: {current["humidity"]}%\nwttr.in · 30 min')}
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(json.dumps({'location':location,'units':units,'result':result,'fetched':time.time()}))
except Exception as error:
    result = {'text':'☁ —', 'tooltip':html.escape(f'Weather unavailable: {error}')}
    try:
        saved = json.loads(cache.read_text())
        if saved['location'] == location and saved['units'] == units:
            result = saved['result']
            result['tooltip'] += '\n⚠ Offline — poslední dostupná data'
    except (OSError, ValueError, KeyError, NameError):
        pass
print(json.dumps(result, ensure_ascii=False))
