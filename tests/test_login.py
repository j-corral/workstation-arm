"""Exercise boot selection with fake system commands; never change host services."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LoginTests(unittest.TestCase):
    def test_kde_installs_system_settings_and_display_support(self):
        source = (ROOT / 'install/02-kde.sh').read_text()
        self.assertIn('systemsettings kscreen', source)
        self.assertIn('systemsettings kscreen-doctor', source)
        self.assertIn('x11-xserver-utils', source)
        self.assertIn('DisplayCommand=/usr/local/lib/workstation/sddm-xsetup', source)
        self.assertIn('org.workstation.splash', source)

    def test_sddm_setup_keeps_fallback_and_only_sets_supported_resolution(self):
        setup = (ROOT / 'config/sddm-xsetup.sh').read_text()
        self.assertIn('/usr/share/sddm/scripts/Xsetup', setup)
        self.assertIn('xrandr --output "$output" --mode 1920x1080', setup)
        self.assertIn('|| true', setup)

    def test_workstation_splash_is_neutral_and_animated(self):
        splash = (ROOT / 'config/workstation-splash/contents/splash/Splash.qml').read_text()
        self.assertIn('Preparing your desktop', splash)
        self.assertIn('Animation.Infinite', splash)
        self.assertNotIn('Apple', splash)

    def run_selection(self, present):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            sessions = work / 'sessions'
            sessions.mkdir()
            if present:
                (sessions / 'plasma.desktop').touch()
            source = (ROOT / 'install/02-kde.sh').read_text()
            source = source.replace('/usr/share/wayland-sessions', str(sessions))
            module = work / 'module.sh'
            module.write_text(source)
            script = r'''
set -Eeuo pipefail
source "$TEST_DIR/module.sh"
need_commands() { :; }
fail() { printf '%s\n' "$*" >&2; return 1; }
dpkg-query() { printf '%s/sessions/plasma.desktop\n' "$TEST_DIR"; }
getent() { printf 'sddm:x:100:100::%s:/bin/false\n' "$TEST_DIR"; }
sudo() {
    printf '%s\n' "$*" >> "$TEST_DIR/calls"
    if [[ $1 == debconf-set-selections ]]; then cat >> "$TEST_DIR/calls"; fi
}
readlink() { printf '/usr/lib/systemd/system/sddm.service\n'; }
kde_configure_login
'''
            result = subprocess.run(['bash', '-c', script], capture_output=True, text=True,
                                    env={**os.environ, 'TEST_DIR': directory, 'WS_TMP': directory,
                                         'WS_ROOT': str(ROOT)})
            calls = (work / 'calls').read_text() if (work / 'calls').exists() else ''
            return result, calls

    def test_selects_sddm_without_interrupting_session(self):
        result, calls = self.run_selection(True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--group Last --key Session plasma.desktop', calls)
        self.assertIn('shared/default-x-display-manager select sddm', calls)
        self.assertIn('systemctl enable --force sddm.service', calls)
        self.assertIn('systemctl set-default graphical.target', calls)
        for forbidden in ('--now', ' restart ', ' stop ', ' start ', 'Autologin'):
            self.assertNotIn(forbidden, calls)

    def test_missing_session_does_not_change_display_manager(self):
        result, calls = self.run_selection(False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('session entry is missing', result.stderr)
        self.assertEqual(calls, '')
