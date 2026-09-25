#!/usr/bin/env python3
"""Backed-up, repeatable deployment of only repository-owned user files."""
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

PRESERVE = {
    '.config/hypr/local.lua', '.config/hypr/brightness.json', '.config/hypr/wallpaper',
    '.config/waybar/weather.json', '.local/share/backgrounds/current-wallpaper.webp',
}
OBSOLETE = (
    '.scripts/update-checker.sh', '.scripts/hypr-brightness-slider.py',
    '.scripts/postinstall.sh',
    '.config/autostart/update-checker.sh.desktop', '.config/autostart/update-checker.desktop',
    '.local/share/applications/update-checker.desktop',
)

def deploy(source, home):
    source, home = source.resolve(), home.resolve()
    if source == home:
        raise ValueError('Use a separate repository checkout, not your home directory.')
    files = []
    for directory in ('.config', '.local', '.scripts', 'Dokumenty'):
        for src in (source / directory).rglob('*'):
            if src.is_file() and not any(part in ('.git', '__pycache__') for part in src.relative_to(source).parts):
                files.append((src, src.relative_to(source)))
    files += [(source / name, Path(name)) for name in ('.zshrc', '.zsh_aliases')]
    # Refuse directory traversal through linked parents before changing any files.
    for relative in [rel for _, rel in files] + [Path(rel) for rel in OBSOLETE] + [Path('.local/state/work-scripts/preflight')]:
        for parent in (home / relative).parents:
            if parent == home:
                break
            if parent.is_symlink():
                raise ValueError(f'Symlinked destination directory: {parent}; resolve it before installation.')
        target = home / relative
        if target.is_dir() and not target.is_symlink():
            raise ValueError(f'Expected a file but found a directory: {target}')
    state = home / '.local/state/work-scripts'
    state.mkdir(parents=True, exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix='install-backup.', dir=state))
    records = []
    def save(relative):
        target = home / relative
        exists = target.exists() or target.is_symlink()
        if exists:
            saved = backup / 'files' / relative
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, saved, follow_symlinks=False)
        records.append({'path': str(relative), 'action': 'replaced' if exists else 'created'})
        (backup / 'manifest.json').write_text(json.dumps(records, indent=2))
    for src, relative in sorted(files):
        target = home / relative
        exists = target.exists() or target.is_symlink()
        if exists and (str(relative) in PRESERVE or relative.parts[0] == 'Dokumenty'):
            continue
        save(relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        # Atomic replacement, including existing file symlinks, never writes through them.
        fd, name = tempfile.mkstemp(prefix='.work-scripts-', dir=target.parent)
        os.close(fd)
        staged = Path(name)
        try:
            shutil.copy2(src, staged)
            if (relative.parts[0] == '.scripts' and src.suffix in ('.sh', '.py')) or relative.parts[:2] == ('.local', 'bin'):
                staged.chmod(staged.stat().st_mode | 0o111)
            if str(relative) in ('.config/qt5ct/qt5ct.conf', '.config/qt6ct/qt6ct.conf'):
                staged.write_text(staged.read_text().replace('@HOME@', str(home)))
            if relative.suffix == '.desktop':
                # Desktop entry string escaping plus Exec argument escaping.
                desktop_home = str(home)
                for char in ('\\', '"', '`', '$'):
                    desktop_home = desktop_home.replace(char, '\\' + char)
                desktop_home = desktop_home.replace('\\', '\\\\')
                staged.write_text(staged.read_text().replace('@HOME@', desktop_home))
            staged.replace(target)
        finally:
            staged.unlink(missing_ok=True)
    for relative in OBSOLETE:
        target = home / relative
        if target.exists() or target.is_symlink():
            save(Path(relative))
            records[-1]['action'] = 'removed'
            (backup / 'manifest.json').write_text(json.dumps(records, indent=2))
            target.unlink()
    for directory in ('1!QUOTES', 'Accountant', 'Our inquires', 'Temp'):
        (home / 'Dokumenty/Ralakde' / directory).mkdir(parents=True, exist_ok=True)
    print(f'Installed work scripts and dotfiles. Backup: {backup}')
    return backup

if __name__ == '__main__':
    deploy(Path(sys.argv[1]), Path(sys.argv[2]))
