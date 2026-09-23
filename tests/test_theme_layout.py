"""First Plasma login replaces panels only once and saves the prior layout."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'config/mactahoe-first-login.sh'


class ThemeLayoutTests(unittest.TestCase):
    def test_layout_autostart_is_independent_of_daily_account_name(self):
        kde = (ROOT / 'install/02-kde.sh').read_text()
        self.assertIn('/usr/local/lib/workstation/mactahoe-first-login', kde)
        self.assertNotIn('Exec=$HOME/.local/bin/workstation-mactahoe-apply', kde)

    def test_first_login_backup_and_idempotency(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config = home / '.config'
            share = home / '.local/share'
            layout = share / 'plasma/look-and-feel/com.github.vinceliuice.MacTahoe-Light/contents/layouts/org.kde.plasma.desktop-layout.js'
            wallpaper = share / 'wallpapers/MacTahoe-Light/contents/images/3840x2160.jpeg'
            for item in (layout, wallpaper):
                item.parent.mkdir(parents=True, exist_ok=True)
                item.touch()
            config.mkdir()
            (config / 'plasma-org.kde.plasma.desktop-appletsrc').write_text('old panels')
            bin_dir = home / 'bin'
            bin_dir.mkdir()
            for command in ('plasma-apply-lookandfeel', 'plasma-apply-wallpaperimage', 'plasma-apply-cursortheme'):
                script = bin_dir / command
                script.write_text('#!/bin/sh\nprintf "%s\\n" "' + command + ' $*" >> "$TEST_CALLS"\n')
                script.chmod(0o755)
            calls = home / 'calls'
            env = {**os.environ, 'HOME': str(home), 'PATH': str(bin_dir) + ':' + os.environ['PATH'],
                   'TEST_CALLS': str(calls), 'XDG_CURRENT_DESKTOP': 'KDE'}
            for _ in range(2):
                result = subprocess.run(['bash', str(SCRIPT)], env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(calls.read_text().count('--resetLayout'), 1)
            backup = home / '.local/state/workstation/theme-backup/plasma-org.kde.plasma.desktop-appletsrc.before-mactahoe'
            self.assertEqual(backup.read_text(), 'old panels')

    def test_gnome_does_not_modify_layout(self):
        with tempfile.TemporaryDirectory() as directory:
            env = {**os.environ, 'HOME': directory, 'XDG_CURRENT_DESKTOP': 'GNOME'}
            result = subprocess.run(['bash', str(SCRIPT)], env=env)
            self.assertEqual(result.returncode, 0)
            self.assertFalse((Path(directory) / '.local/state/workstation/theme-backup').exists())

    def test_selected_desktop_apps_are_reconciled_in_the_existing_dock(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config = home / '.config'
            (config / 'workstation').mkdir(parents=True)
            (config / 'workstation/components.conf').write_text(
                'desktop_obsidian=1\n'
                'desktop_bitwarden=1\n'
            )
            (config / 'plasma-org.kde.plasma.desktop-appletsrc').write_text(
                '[Containments][7][Applets][12]\n'
                'plugin=org.kde.plasma.icontasks\n'
                '[Containments][7][Applets][13]\n'
                'plugin=org.kde.plasma.kickoff\n'
            )
            share = home / '.local/share'
            layout = share / 'plasma/look-and-feel/com.github.vinceliuice.MacTahoe-Light/contents/layouts/org.kde.plasma.desktop-layout.js'
            wallpaper = share / 'wallpapers/MacTahoe-Light/contents/images/3840x2160.jpeg'
            for item in (layout, wallpaper):
                item.parent.mkdir(parents=True, exist_ok=True)
                item.touch()
            bin_dir = home / 'bin'
            bin_dir.mkdir()
            for command in ('plasma-apply-lookandfeel', 'plasma-apply-wallpaperimage', 'plasma-apply-cursortheme'):
                script = bin_dir / command
                script.write_text('#!/bin/sh\nexit 0\n')
                script.chmod(0o755)
            (bin_dir / 'kreadconfig6').write_text(
                '#!/bin/sh\nprintf "%s" "applications:org.kde.dolphin.desktop,applications:bruno.desktop"\n'
            )
            (bin_dir / 'kwriteconfig6').write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$TEST_WRITE"\n')
            (bin_dir / 'kreadconfig6').chmod(0o755)
            (bin_dir / 'kwriteconfig6').chmod(0o755)
            result = subprocess.run(
                ['bash', str(SCRIPT)],
                env={**os.environ, 'HOME': str(home), 'PATH': str(bin_dir) + ':' + os.environ['PATH'],
                     'TEST_WRITE': str(home / 'write'), 'XDG_CURRENT_DESKTOP': 'KDE'},
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            write = (home / 'write').read_text()
            self.assertIn('applications:org.kde.dolphin.desktop', write)
            self.assertNotIn('applications:bruno.desktop', write)
            self.assertIn('applications:md.obsidian.Obsidian.desktop', write)
            self.assertIn('applications:com.bitwarden.desktop', write)
            self.assertIn('--key visibility 1', write)
            self.assertIn('--key icon view-grid', write)
