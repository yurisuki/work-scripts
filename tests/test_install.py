import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('deploy', ROOT / 'install/deploy.py')
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)

class InstallationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "new user's home"
        self.home.mkdir()

    def test_clean_install_and_repeat_preserves_personal_files(self):
        deploy.deploy(ROOT, self.home)
        weather = self.home / '.config/waybar/weather.json'
        weather.write_text('{"location":"Brno","units":"m"}')
        local = self.home / '.config/hypr/local.lua'
        local.write_text('-- laptop settings')
        template = self.home / 'Dokumenty/Ralakde/Our inquires/!1Inquiry template.xlsx'
        template.write_bytes(b'personal document')
        old = self.home / '.scripts/update-checker.sh'
        old.write_text('obsolete')
        backup = deploy.deploy(ROOT, self.home)
        self.assertEqual(json.loads(weather.read_text())['location'], 'Brno')
        self.assertEqual(local.read_text(), '-- laptop settings')
        self.assertEqual(template.read_bytes(), b'personal document')
        self.assertFalse(old.exists())
        self.assertEqual((backup / 'files/.scripts/update-checker.sh').read_text(), 'obsolete')
        self.assertNotIn('@HOME@', (self.home / '.config/qt6ct/qt6ct.conf').read_text())
        self.assertTrue(os.access(self.home / '.scripts/bar-calendar.sh', os.X_OK))
        self.assertTrue((self.home / '.scripts/dhl-crop.py').is_file())
        self.assertTrue((self.home / '.scripts/print_label.sh').is_file())

    def test_file_symlink_is_backed_up_without_changing_target(self):
        external = Path(self.temp.name) / 'external'
        external.write_text('keep me')
        (self.home / '.zshrc').symlink_to(external)
        backup = deploy.deploy(ROOT, self.home)
        self.assertEqual(external.read_text(), 'keep me')
        self.assertTrue((backup / 'files/.zshrc').is_symlink())
        self.assertFalse((self.home / '.zshrc').is_symlink())

    def test_symlinked_parent_rejected_before_writes(self):
        external = Path(self.temp.name) / 'external-config'
        external.mkdir()
        (self.home / '.config').symlink_to(external)
        with self.assertRaises(ValueError):
            deploy.deploy(ROOT, self.home)
        self.assertEqual(list(external.iterdir()), [])
        self.assertFalse((self.home / '.zshrc').exists())

    def test_desktop_entries(self):
        deploy.deploy(ROOT, self.home)
        for desktop in (self.home / '.local/share/applications').glob('*.desktop'):
            subprocess.run(['desktop-file-validate', str(desktop)], check=True, capture_output=True)
            self.assertNotIn('@HOME@', desktop.read_text())
        # Verify the parsed command resolves to a real executable, including spaces.
        import gi
        from gi.repository import Gio
        for desktop in (self.home / '.local/share/applications').glob('*.desktop'):
            app = Gio.DesktopAppInfo.new_from_filename(str(desktop))
            self.assertIsNotNone(app)

    def test_full_installer_with_mock_package_managers(self):
        """Run the real full flow without modifying host packages or services."""
        bin_dir = Path(self.temp.name) / 'bin'
        bin_dir.mkdir()
        log = Path(self.temp.name) / 'commands'
        stub = '''#!/usr/bin/env bash
printf '%s %s\\n' "$(basename "$0")" "$*" >> "$INSTALL_TEST_LOG"
case "$(basename "$0")" in
  pacman) [[ ${1:-} != -Q ]] || echo 'hyprland 0.56.2-1' ;;
  xdg-user-dir) echo "$HOME/Downloads" ;;
  sudo)
    if [[ ${1:-} == mktemp ]]; then echo "$HOME/greetd-backup"; fi ;;
esac
exit 0
'''
        for command in ('sudo', 'pacman', 'yay', 'uv', 'start-hyprland', 'xdg-user-dirs-update', 'xdg-user-dir', 'fc-cache', 'update-desktop-database', 'systemctl'):
            path = bin_dir / command
            path.write_text(stub)
            path.chmod(0o755)
        env = dict(os.environ, HOME=str(self.home), PATH=f'{bin_dir}:/usr/bin:/bin', INSTALL_TEST_LOG=str(log))
        env.pop('XDG_CONFIG_HOME', None)
        subprocess.run(['bash', str(ROOT / 'install.sh'), '--greetd'], env=env, check=True, capture_output=True)
        commands = log.read_text()
        self.assertIn('sudo pacman -Syu --needed', commands)
        self.assertIn('yay -S --needed', commands)
        self.assertIn('uv tool install calcure==3.4', commands)
        self.assertIn('sudo systemctl enable greetd.service', commands)
        self.assertNotIn('--now greetd', commands)
        unit = self.home / '.config/systemd/user/quote-download-watcher.service'
        self.assertIn(f'ExecStart="{self.home}/.scripts/quote-download-watcher.sh"', unit.read_text())
        self.assertIn('--cmd start-hyprland', (self.home / '.config/greetd/config.toml').read_text())

    def test_package_failure_stops_before_deployment(self):
        bin_dir = Path(self.temp.name) / 'bin'
        bin_dir.mkdir()
        for command, body in [('pacman', 'exit 0'), ('sudo', '[[ ${1:-} == -v ]]')]:
            path = bin_dir / command
            path.write_text('#!/usr/bin/env bash\n' + body + '\n')
            path.chmod(0o755)
        env = dict(os.environ, HOME=str(self.home), PATH=f'{bin_dir}:/usr/bin:/bin')
        result = subprocess.run(['bash', str(ROOT / 'install.sh')], env=env, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / '.config').exists())

if __name__ == '__main__':
    unittest.main()
