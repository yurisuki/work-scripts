"""Shared wttr.in settings and readable service errors."""
import json
from pathlib import Path
import unicodedata
from urllib.error import HTTPError, URLError


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
