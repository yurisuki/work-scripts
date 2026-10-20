#!/usr/bin/env python3
"""Local file and Brave sources for desktop search."""
import json
import os
from pathlib import Path
import shutil
import sqlite3
import re
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit, quote_plus


def clean(value):
    return str(value).replace('\0', '').replace('\n', ' ').replace('\r', ' ').replace('\x1f', ' ')


def row(title, target, icon, extra=''):
    info = json.dumps(target, ensure_ascii=True)
    print(f'{clean(title)}\0icon\x1f{icon}\x1finfo\x1f{info}\x1fmeta\x1f{clean(extra)}')


def file_entries():
    # Skip hidden/system/build directories; never follow symlinks into mounts.
    command = ['fd', '--absolute-path', '--color', 'never', '--type', 'f', '--type', 'd',
               '--max-depth', '8', '--exclude', 'node_modules', '--exclude', 'go',
               '--exclude', 'vendor', '--exclude', 'iCloud', '.', str(Path.home())]
    try:
        with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True) as files:
            try:
                for index, name in enumerate(files.stdout):
                    if index >= 50000:
                        break
                    path = Path(name.rstrip('\n'))
                    if path.is_dir():
                        icon = 'folder'
                    else:
                        icon = 'text-x-generic'
                    row(str(path.relative_to(Path.home())), {'path': str(path)}, icon)
            finally:
                if files.poll() is None:
                    files.terminate()
    except OSError:
        pass


def bookmark_entries(node):
    if node.get('type') == 'url':
        yield node.get('name', ''), node.get('url', '')
    for child in node.get('children', []):
        yield from bookmark_entries(child)


def bookmark_favicons(urls, root=None):
    """Read icons from private temporary snapshots: Brave can lock its live DB."""
    if not urls:
        return {}
    root = root or Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'BraveSoftware/Brave-Browser'
    found = {}
    query = ('SELECT b.image_data FROM icon_mapping m JOIN favicon_bitmaps b '
             'ON b.icon_id=m.icon_id WHERE {condition} AND b.image_data IS NOT NULL '
             'ORDER BY b.width DESC, b.last_updated DESC LIMIT 1')
    for profile in [root / 'Default', *sorted(root.glob('Profile *'))]:
        live = profile / 'Favicons'
        if not live.is_file():
            continue
        try:
            with tempfile.TemporaryDirectory(prefix='desktop-search-icons-') as temporary:
                snapshot = Path(temporary) / 'Favicons'
                shutil.copyfile(live, snapshot)
                for suffix in ('-wal', '-journal'):
                    extra = Path(str(live) + suffix)
                    if extra.exists():
                        shutil.copyfile(extra, Path(str(snapshot) + suffix))
                with sqlite3.connect(snapshot, timeout=0.2) as database:
                    for url in urls:
                        if url in found:
                            continue
                        result = database.execute(query.format(condition='m.page_url = ?'), (url,)).fetchone()
                        if not result:
                            parsed = urlsplit(url)
                            origin = f'{parsed.scheme}://{parsed.netloc}/'
                            pattern = origin.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_') + '%'
                            result = database.execute(query.format(condition="m.page_url LIKE ? ESCAPE '\\'"), (pattern,)).fetchone()
                        if result and 0 < len(result[0]) <= 262144:
                            found[url] = result[0]
        except (OSError, sqlite3.Error, ValueError):
            continue
    return found


def brave_entries():
    root = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'BraveSoftware/Brave-Browser'
    profiles = [root / 'Default', *sorted(root.glob('Profile *'))]
    seen = set()
    for profile in profiles:
        try:
            bookmarks = json.loads((profile / 'Bookmarks').read_text())
            for node in bookmarks.get('roots', {}).values():
                for title, url in bookmark_entries(node):
                    if url in seen or urlsplit(url).scheme not in ('http', 'https'):
                        continue
                    seen.add(url)
                    row(f'★ {title or url} · {url}', {'url': url}, 'user-bookmarks', profile.name)
        except (OSError, ValueError, TypeError):
            pass
    for profile in profiles:
        history = profile / 'History'
        if not history.is_file():
            continue
        try:
            with sqlite3.connect(history.as_uri() + '?mode=ro', uri=True, timeout=0.2) as database:
                records = database.execute(
                    'SELECT title, url FROM urls WHERE hidden=0 ORDER BY last_visit_time DESC LIMIT 5000')
                for title, url in records:
                    if url in seen or urlsplit(url).scheme not in ('http', 'https'):
                        continue
                    seen.add(url)
                    row(f'{title or url} · {url}', {'url': url}, 'document-open-recent', profile.name)
        except (OSError, sqlite3.Error, ValueError):
            pass


def search_provider():
    root = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'BraveSoftware/Brave-Browser'
    profile = 'Default'
    try:
        last = json.loads((root / 'Local State').read_text()).get('profile', {}).get('last_used', 'Default')
        if last == 'Default' or re.fullmatch(r'Profile \d+', last):
            profile = last
    except (OSError, ValueError, TypeError):
        pass
    for filename in ('Preferences', 'Secure Preferences'):
        try:
            preferences = json.loads((root / profile / filename).read_text())
            data = preferences.get('default_search_provider_data', {})
            for key in ('template_url_data', 'mirrored_template_url_data'):
                provider = data.get(key, {})
                if provider.get('url') and '{searchTerms}' in provider['url']:
                    return provider.get('short_name', 'default search engine'), provider['url'], profile
        except (OSError, ValueError, TypeError):
            continue
    raise ValueError('Could not read Brave default search engine')


def search_url(template, query):
    template = template.replace('{google:baseURL}', 'https://www.google.com/')
    template = template.replace('{searchTerms}', quote_plus(query))
    template = template.replace('{inputEncoding}', 'UTF-8').replace('{outputEncoding}', 'UTF-8')
    template = re.sub(r'\{[^{}]+\}', '', template)
    if urlsplit(template).scheme not in ('http', 'https'):
        raise ValueError('Unsupported search URL')
    return template


def activate(info):
    if 'search' in info:
        _, template, profile = search_provider()
        browser = shutil.which('brave') or shutil.which('brave-browser')
        if browser:
            subprocess.Popen([browser, '--profile-directory=' + profile, '--new-tab', search_url(template, info['search'])],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif 'command' in info:
        subprocess.Popen([os.environ.get('SHELL') or '/bin/bash', '-ic', info['command']],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    elif 'path' in info:
        path = Path(info['path'])
        if path.is_absolute() and path.exists():
            subprocess.Popen(['xdg-open', str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif 'url' in info and urlsplit(info['url']).scheme in ('http', 'https'):
        browser = shutil.which('brave') or shutil.which('brave-browser')
        if browser:
            subprocess.Popen([browser, '--new-tab', info['url']], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    if os.environ.get('ROFI_RETV', '0') != '0':
        if os.environ.get('ROFI_RETV') == '1':
            try:
                activate(json.loads(os.environ.get('ROFI_INFO', '{}')))
            except (OSError, ValueError, TypeError):
                pass
        return
    print('\0no-custom\x1ftrue')
    if sys.argv[1:] == ['files']:
        file_entries()
    elif sys.argv[1:] == ['brave']:
        brave_entries()


if __name__ == '__main__':
    try:
        main()
    except BrokenPipeError:
        pass
