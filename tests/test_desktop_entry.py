"""Desktop launchers keep vendor icons and stay inside the test home."""
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DesktopEntryTests(unittest.TestCase):
    def test_zed_launcher_includes_bundled_icon(self):
        with tempfile.TemporaryDirectory() as home:
            binary = Path(home) / '.local/zed.app/bin/zed'
            icon = Path(home) / '.local/zed.app/share/icons/hicolor/512x512/apps/zed.png'
            subprocess.run(
                [sys.executable, str(ROOT / 'tools/desktop_entry.py'), 'zed', 'Zed', str(binary), str(icon)],
                check=True, env={**os.environ, 'HOME': home},
            )
            launcher = Path(home) / '.local/share/applications/workstation-zed.desktop'
            self.assertIn(f'Icon={icon}\n', launcher.read_text())
            self.assertIn(f'Exec="{binary}" %U\n', launcher.read_text())


if __name__ == '__main__':
    unittest.main()
