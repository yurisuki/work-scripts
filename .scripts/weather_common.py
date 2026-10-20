"""Shared wttr.in settings and readable service errors."""
import json
from pathlib import Path
import unicodedata
from urllib.error import HTTPError, URLError


def weather_icon(code):
    """Map wttr.in's condition codes to shared weather symbols."""
    code = str(code)
    if code == '113':
        return '☀'
    if code == '116':
        return '🌤'
    if code in {'143', '248', '260'}:
        return '🌫'
    if code in {'200', '386', '389', '392', '395'}:
        return '⛈'
    if code in {'179', '182', '185', '227', '230', '281', '284', '311', '314',
                '317', '320', '323', '326', '329', '332', '335', '338', '350',
                '362', '365', '368', '371', '374', '377'}:
        return '❄'
    if code in {'176', '263', '266', '293', '296', '299', '302', '305', '308',
                '353', '356', '359'}:
        return '🌧'
    return '☁'


def read_settings():
    settings = json.loads((Path.home() / '.config/waybar/weather.json').read_text())
    location = settings.get('location', '').strip()
    units = settings.get('units', 'm')
    if units not in ('m', 'u'):
        raise ValueError('Units must be m or u.')
    # wttr.in can fail on Czech diacritics even when the plain name resolves.
    # Keep the user's display name; normalize only the service query.
    query = ''.join(
        char for char in unicodedata.normalize('NFKD', location)
        if not unicodedata.combining(char)
    ).casefold()
    query = ' '.join(query.split())
    return {'location': location, 'query': query, 'units': units}


def error_message(error):
    if isinstance(error, HTTPError):
        detail = error.read(512).decode('utf-8', errors='replace').lower()
        if error.code == 404 or 'location not found' in detail or 'unknown location' in detail:
            return 'wttr.in could not find this location. Try a more specific place name in weather.json.'
        if error.code == 429:
            return 'wttr.in is temporarily limiting requests. Try again later.'
        return f'wttr.in is temporarily unavailable (HTTP {error.code}).'
    if isinstance(error, (TimeoutError, URLError)):
        return 'wttr.in is not responding or the internet connection is unavailable.'
    return str(error)
