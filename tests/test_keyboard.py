"""Offline checks for persistent keyboard configuration, without touching the host."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('keyboard_config', ROOT / 'tools/keyboard_config.py')
keyboard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(keyboard)


class KeyboardTests(unittest.TestCase):
    def test_existing_settings_preserved_and_rerun_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'keyboard'
            path.write_text('# local configuration\nXKBMODEL="pc104"\nXKBLAYOUT="us"\n'
                            'XKBLAYOUT="gb"\nXKBVARIANT="intl"\n'
                            'XKBOPTIONS="compose:ralt"\nBACKSPACE="guess"\n')
            path.chmod(0o640)
            keyboard.update(path)
            expected = ('# local configuration\nXKBMODEL="pc105"\nXKBLAYOUT="fr"\n'
                        'XKBVARIANT=""\nXKBOPTIONS="compose:ralt"\nBACKSPACE="guess"\n')
            self.assertEqual(path.read_text(), expected)
            self.assertEqual(path.stat().st_mode & 0o777, 0o640)
            before = path.stat().st_mtime_ns
            keyboard.update(path)
            self.assertEqual(path.stat().st_mtime_ns, before)

    def test_missing_keys_and_symlink_refusal(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'keyboard'
            path.write_text('# keep this comment')
            keyboard.update(path)
            self.assertEqual(path.read_text(), '# keep this comment\nXKBMODEL="pc105"\nXKBLAYOUT="fr"\nXKBVARIANT=""\n')
            link = Path(directory) / 'link'
            link.symlink_to(path)
            before = path.read_bytes()
            with self.assertRaises(ValueError):
                keyboard.update(link)
            self.assertEqual(path.read_bytes(), before)
