#!/usr/bin/env python3
"""Render the clock locale from system settings at each Waybar start."""
import json
import os
import subprocess
from pathlib import Path

home=Path.home()
settings={}
for path in (Path('/etc/locale.conf'),home/'.config/locale.conf'):
    if path.exists():
        for line in path.read_text().splitlines():
            if '=' in line and not line.lstrip().startswith('#'):
                key,value=line.split('=',1)
                settings[key.strip()]=value.strip().strip('\"\'')
config=json.loads((home/'.config/waybar/config.jsonc').read_text())
config['clock']['locale']=settings.get('LC_TIME',settings.get('LANG',os.environ.get('LANG','C.UTF-8')))
runtime=Path(os.environ['XDG_RUNTIME_DIR'])/'violet-waybar.json'
runtime.write_text(json.dumps(config,ensure_ascii=False))
env=os.environ.copy()
env.pop('LC_ALL',None)
env['LC_TIME']=config['clock']['locale']
subprocess.Popen([str(home/'.scripts/hypr-workspace.py'), 'watch', str(os.getpid())],
                 stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
os.execvpe('waybar',['waybar','-c',str(runtime),'-s',str(home/'.config/waybar/style.css')],env)
