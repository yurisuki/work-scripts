#!/usr/bin/env python3
"""Exercise hardware absence and PAM edits without changing system authentication."""
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    'fingerprint', Path(__file__).resolve().parents[1] / '.scripts/setup-fingerprint.py')
fingerprint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fingerprint)

PAM = ('auth required pam_securetty.so\nauth requisite pam_nologin.so\n'
       'auth       include      system-local-login\n'
       'account include system-local-login\nsession include system-local-login\n')


class FingerprintTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.home = Path(self.directory.name)
        self.addCleanup(patch.stopall)
        patch('pathlib.Path.home', return_value=self.home).start()
        patch.object(fingerprint.os, 'geteuid', return_value=1000).start()
        patch('sys.stdout', new_callable=io.StringIO).start()

    def run_action(self, action):
        with patch('sys.argv', ['setup-fingerprint.py', action]):
            fingerprint.main()

    def test_no_reader_auto_leaves_files_and_pam_untouched(self):
        with patch.object(fingerprint, 'reader_ready', return_value=False), \
                patch.object(fingerprint.subprocess, 'run') as command:
            self.run_action('auto')
            self.assertEqual(list(self.home.iterdir()), [])
            command.assert_not_called()

    def test_no_reader_explicit_enable_fails(self):
        with patch.object(fingerprint, 'reader_ready', return_value=False):
            with self.assertRaises(SystemExit) as error:
                self.run_action('enable')
            self.assertEqual(error.exception.code, 1)

    def test_auto_enables_ready_reader_but_preserves_explicit_disable(self):
        with patch.object(fingerprint, 'reader_ready', return_value=True):
            self.run_action('auto')
            config = self.home / '.config/hypr/fingerprint.conf'
            self.assertIn('enabled = true', config.read_text())
            self.run_action('disable')
            self.run_action('auto')
            self.assertIn('enabled = false', config.read_text())

    def test_pam_enable_is_idempotent_and_disable_restores_original(self):
        target = self.home / 'greetd'
        target.write_text(PAM)
        with patch('pathlib.Path.is_file', return_value=True):
            fingerprint.configure_pam(True, target)
            fingerprint.configure_pam(True, target)
        self.assertEqual(target.read_text().count('pam_fprintd.so'), 1)
        self.assertIn('auth       include      system-local-login', target.read_text())
        self.assertEqual(len(list(self.home.glob('greetd.backup.*'))), 1)
        fingerprint.configure_pam(False, target)
        self.assertEqual(target.read_text(), PAM)

    def test_unknown_or_unmanaged_pam_is_not_changed(self):
        target = self.home / 'greetd'
        for content in ('auth include other-login\n', PAM + 'auth sufficient pam_fprintd.so\n'):
            target.write_text(content)
            with patch('pathlib.Path.is_file', return_value=True):
                with self.assertRaises(RuntimeError):
                    fingerprint.configure_pam(True, target)
            self.assertEqual(target.read_text(), content)
        fingerprint.configure_pam(False, target)
        self.assertEqual(target.read_text(), content)


if __name__ == '__main__':
    unittest.main()
