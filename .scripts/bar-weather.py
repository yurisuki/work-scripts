#!/usr/bin/env python3
"""wttr.in weather; Waybar schedules a request every 30 minutes."""
import fcntl
import time
import html
import json
from pathlib import Path
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen
from weather_common import error_message, read_settings

cache = Path.home() / '.cache/waybar/weather.json'
cache.parent.mkdir(parents=True, exist_ok=True)
lock = (cache.parent / 'weather.lock').open('w')
fcntl.flock(lock, fcntl.LOCK_EX)
try:
    settings = read_settings()
    location = settings['location']
    query = settings['query']
    if not location:
        result = {'text': '☁ ⚙', 'tooltip': 'Right-click to set location in weather.json (for example, Prague).'}
    else:
        units = settings.get('units', 'm')
        if units not in ('m', 'u'):
            raise ValueError('units must be m or u')
        try:
            saved = json.loads(cache.read_text())
            if saved.get('query', saved['location']) == query and saved['units'] == units and saved.get('language') == 'en' and time.time() - saved.get('fetched', 0) < 1800:
                print(json.dumps(saved['result'], ensure_ascii=False))
                raise SystemExit(0)
        except (OSError, ValueError, KeyError):
            pass
        url = 'https://wttr.in/' + quote(query, safe='') + '?' + urlencode({'format':'j1', 'lang':'en', units:''})
        with urlopen(Request(url, headers={'User-Agent':'VioletNight-Waybar/1.0'}), timeout=12) as response:
            current = json.load(response)['current_condition'][0]
        temperature = current['temp_F' if units == 'u' else 'temp_C']
        description = current['weatherDesc'][0]['value']
        result = {'text': f'☁ {temperature}°' + ('F' if units == 'u' else 'C'), 'tooltip': html.escape(f'{location}: {description}\nFeels like: {current.get("FeelsLikeF" if units == "u" else "FeelsLikeC", "—")}°{"F" if units == "u" else "C"}\nHumidity: {current["humidity"]}%\nWind: {current.get("windspeedMiles" if units == "u" else "windspeedKmph", "—")} {"mph" if units == "u" else "km/h"} {current.get("winddir16Point", "")}\nPrecipitation: {current.get("precipMM", "—")} mm\nwttr.in · 30 min')}
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(json.dumps({'location':location,'query':query,'units':units,'language':'en','result':result,'fetched':time.time()}))
except Exception as error:
    result = {'text':'☁ —', 'tooltip':html.escape(f'Weather unavailable: {error_message(error)}')}
    try:
        saved = json.loads(cache.read_text())
        if saved.get('query', saved['location']) == query and saved['units'] == units and saved.get('language') == 'en':
            result = saved['result']
            result['tooltip'] += '\n⚠ Offline — last available data'
    except (OSError, ValueError, KeyError, NameError):
        pass
print(json.dumps(result, ensure_ascii=False))
