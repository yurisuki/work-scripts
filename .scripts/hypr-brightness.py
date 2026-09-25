#!/usr/bin/env python3
"""Coalesce wheel events into the latest target, with a single DDC worker."""
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

runtime = Path(os.environ['XDG_RUNTIME_DIR'])
state_path = runtime / 'violet-brightness.json'
lock_path = runtime / 'violet-brightness-state.lock'
worker_path = runtime / 'violet-brightness-worker.lock'

def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL, timeout=6).strip()

def read_state():
    try:
        return json.loads(state_path.read_text())
    except (OSError, ValueError):
        return {}

def write_state(state):
    tmp = state_path.with_suffix('.tmp')
    tmp.write_text(json.dumps(state))
    tmp.replace(state_path)

def hardware():
    devices = sorted(Path('/sys/class/backlight').glob('*'))
    if devices:
        device = devices[0]
        maximum = int((device/'max_brightness').read_text())
        current = int((device/'brightness').read_text())
        return {'device':device.name, 'maximum':maximum, 'target':round(current*100/maximum)}
    config = Path.home()/'.config/hypr/brightness.json'
    display = str(json.loads(config.read_text()).get('ddc_display', 1)) if config.exists() else '1'
    output = run('ddcutil','--display',display,'--brief','getvcp','10')
    match = re.search(r'VCP\s+10\s+C\s+(\d+)\s+(\d+)',output)
    if not match:
        raise RuntimeError('Monitor did not report brightness')
    current, maximum = map(int,match.groups())
    return {'display':display,'maximum':maximum,'target':round(current*100/maximum)}

def notify_bar():
    subprocess.run(['pkill','-RTMIN+8','-x','waybar'],check=False)

def worker():
    with worker_path.open('w') as worker_lock:
        try:
            fcntl.flock(worker_lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:
            return
        # Briefly combine wheel events before the first hardware write.
        time.sleep(.10)
        while True:
            with lock_path.open('w') as lock:
                fcntl.flock(lock,fcntl.LOCK_EX)
                state=read_state()
                if not state.get('pending'):
                    # Release worker while holding the state lock: no lost wakeups.
                    fcntl.flock(worker_lock,fcntl.LOCK_UN)
                    return
                target=state['target']
            try:
                if 'device' in state:
                    run('brightnessctl','-d',state['device'],'set',f'{target}%')
                else:
                    run('ddcutil','--display',state['display'],'setvcp','10',str(round(target*state['maximum']/100)))
                error=''
            except (OSError,subprocess.SubprocessError) as exc:
                error=str(exc)
            with lock_path.open('w') as lock:
                fcntl.flock(lock,fcntl.LOCK_EX)
                latest=read_state()
                if latest.get('target')==target or error:
                    latest['pending']=False
                latest['error']=error
                latest['updated']=time.time()
                write_state(latest)
            notify_bar()

def main():
    action=sys.argv[1] if len(sys.argv)>1 else 'status'
    if action=='worker':
        worker(); return
    if action not in ('status','up','down','set'):
        raise ValueError('Expected status, up, down or set PERCENT')
    with lock_path.open('w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        state=read_state()
        # No repeated DDC reads during scrolling or status refreshes.
        if not state or (action=='status' and not state.get('pending') and time.time()-state.get('updated',0)>60):
            state=hardware(); state['updated']=time.time(); write_state(state)
        if action=='status':
            failed=state.get('error')
            print(json.dumps({'text':'󰃠  —' if failed else f'󰃠  {state["target"]}%', 'tooltip':failed or 'Jas · kolečkem změnit', 'class':'unavailable' if failed else 'available','percentage':state['target']}))
            return
        target=int(sys.argv[2]) if action=='set' else state['target']+(5 if action=='up' else -5)
        state.update(target=max(5,min(100,target)),pending=True,error='',updated=time.time())
        write_state(state)
        subprocess.Popen([sys.executable,__file__,'worker'],stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
    notify_bar()

if __name__=='__main__':
    try:
        main()
    except (OSError,ValueError,RuntimeError,subprocess.SubprocessError,KeyError,IndexError,ZeroDivisionError) as exc:
        if len(sys.argv)<2 or sys.argv[1]=='status':
            print(json.dumps({'text':'󰃠 —','tooltip':str(exc),'class':'unavailable'}))
        else:
            subprocess.run(['notify-send','Brightness unavailable',str(exc)],check=False)
            sys.exit(1)
