#!/usr/bin/env python3
"""Offline safety tests. These do NOT substitute for an Ubuntu VM install."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import stat
import struct
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('managed_block', ROOT / 'tools/managed_block.py')
blocks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(blocks)


class SafetyTests(unittest.TestCase):
    def test_broken_awk_stops_with_actionable_diagnostic(self):
        env = dict(os.environ, WS_ROOT=str(ROOT), WS_REPORT='')
        script = '''
set -Eeuo pipefail
source "$WS_ROOT/lib/logging.sh"
source "$WS_ROOT/lib/detection.sh"
awk() { return 133; }
check_awk
printf 'SHOULD_NOT_CONTINUE'
'''
        result = subprocess.run(['bash', '-c', script], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 133)
        self.assertIn('awk cannot run', result.stdout)
        self.assertIn('file -L /usr/bin/awk', result.stdout)
        self.assertNotIn('SHOULD_NOT_CONTINUE', result.stdout)

    def test_managed_section_preserves_content_mode_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / '.zshrc'
            path.write_text('export USER_SETTING="keep me"\n')
            path.chmod(0o640)
            blocks.update(path, 'shell', 'first\n')
            blocks.update(path, 'shell', 'updated\n')
            expected = path.read_bytes()
            blocks.update(path, 'shell', 'updated\n')
            self.assertEqual(path.read_bytes(), expected)
            self.assertTrue(expected.startswith(b'export USER_SETTING="keep me"\n'))
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o640)
            self.assertEqual(expected.count(b'# >>> workstation:shell >>>'), 1)

    def test_malformed_markers_and_symlink_fail_without_changes(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / '.zshrc'
            path.write_text('# >>> workstation:shell >>>\nprivate config\n')
            before = path.read_bytes()
            with self.assertRaises(ValueError):
                blocks.update(path, 'shell', 'new')
            self.assertEqual(path.read_bytes(), before)
            link = Path(d) / 'link'
            link.symlink_to(path)
            with self.assertRaises(ValueError):
                blocks.update(link, 'shell', 'new')

    def test_dry_runs_do_not_write_to_home_or_invoke_network_sudo(self):
        with tempfile.TemporaryDirectory() as d:
            home = Path(d) / 'home'
            home.mkdir()
            commands = Path(d) / 'bin'
            commands.mkdir()
            for name in ('sudo', 'curl', 'apt-get', 'wget'):
                script = commands / name
                script.write_text('#!/bin/sh\necho UNEXPECTED_EXTERNAL_OPERATION >&2\nexit 99\n')
                script.chmod(0o755)
            env = dict(os.environ, HOME=str(home), PATH=str(commands) + ':' + os.environ['PATH'])
            cases = [[], ['--skip', 'desktop']] + [['--only', x] for x in ('system', 'kde', 'shell', 'git', 'runtimes', 'docker', 'dev', 'desktop', 'network', 'security', 'ai')]
            for args in cases:
                result = subprocess.run(['bash', str(ROOT / 'bootstrap.sh'), '--dry-run', *args], env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn('UNEXPECTED_EXTERNAL_OPERATION', result.stderr)
                self.assertNotIn('[INSTALLED]', result.stdout)
                if args[:1] == ['--only']:
                    plans = [x for x in result.stdout.splitlines() if '[PLANNED]' in x]
                    self.assertGreaterEqual(len(plans), 1 if args[-1] == 'ai' else 2)
            self.assertEqual(list(home.rglob('*')), [])

    def test_argument_errors_do_not_run_installation(self):
        for args in (['--only'], ['--only', 'invalid'], ['--only', 'docker dev'], ['--skip', 'desktop', '--only', 'shell'], ['--wat']):
            result = subprocess.run(['bash', str(ROOT / 'bootstrap.sh'), *args], capture_output=True)
            self.assertEqual(result.returncode, 2)

    def test_action_errexit_and_required_optional_boundaries(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            shutil.copytree(ROOT / 'lib', root / 'lib')
            (root / 'install').mkdir()
            report = root / 'report'
            report.mkdir()
            (root / 'install/fixture.sh').write_text('explode() { false; touch "$WS_REPORT/should-not-exist"; }\n')
            env = dict(os.environ, WS_ROOT=str(root), WS_MODULE='fixture.sh', WS_REPORT=str(report), WS_DRY_RUN='0')
            for importance, expected in [('optional', 0), ('required', 1)]:
                code = 'set -Eeuo pipefail; source "$WS_ROOT/lib/common.sh"; component ' + importance + ' Example explode fixture; touch "$WS_REPORT/continued"'
                result = subprocess.run(['bash', '-c', code], env=env, capture_output=True)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertFalse((report / 'should-not-exist').exists())
                self.assertEqual((report / 'continued').exists(), importance == 'optional')
                (report / 'continued').unlink(missing_ok=True)
            self.assertEqual((report / 'results.tsv').read_text().count('FAILED\tExample'), 2)

    def test_architecture_rejected_before_execution(self):
        with tempfile.TemporaryDirectory() as d:
            binary = Path(d) / 'binary'
            for architecture, expected in [(183, 0), (62, 1)]:
                header = bytearray(20)
                header[:6] = b'\x7fELF\x02\x01'
                struct.pack_into('<H', header, 18, architecture)
                binary.write_bytes(header)
                r = subprocess.run(['python3', str(ROOT / 'tools/artifacts.py'), 'elf', str(binary)], capture_output=True)
                self.assertEqual(r.returncode, expected)

    def test_archive_path_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            archive = Path(d) / 'unsafe.zip'
            with zipfile.ZipFile(archive, 'w') as z:
                z.writestr('../outside', 'no')
            r = subprocess.run(['python3', str(ROOT / 'tools/artifacts.py'), 'extract', str(archive), str(Path(d) / 'out')], capture_output=True)
            self.assertNotEqual(r.returncode, 0)
            self.assertFalse((Path(d) / 'outside').exists())

    def test_checksum_mismatch_stops_before_following_command(self):
        with tempfile.TemporaryDirectory() as d:
            env = dict(os.environ, WS_ROOT=str(ROOT), WS_REPORT='', WS_DRY_RUN='0', WS_TEST_DIR=d)
            script = r'''
set -Eeuo pipefail
source "$WS_ROOT/lib/common.sh"
# A local payload substitutes only the transport; checksum enforcement is real.
download() { printf 'corrupted artifact' > "$2"; }
if ! command -v sha256sum >/dev/null; then sha256sum() { shasum -a 256 "$@"; }; fi
locked_download bun "$WS_TEST_DIR/archive"
touch "$WS_TEST_DIR/executed"
'''
            result = subprocess.run(['bash', '-c', script], env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Checksum mismatch', result.stdout)
            self.assertFalse((Path(d) / 'executed').exists())

    def test_locks_have_explicit_architecture_and_digest(self):
        locks = json.loads((ROOT / 'config/downloads.json').read_text())
        self.assertEqual(len(locks), 8)
        for item in locks.values():
            self.assertTrue(item['url'].startswith('https://'))
            self.assertRegex(item['url'], r'arm64|aarch64')
            self.assertRegex(item['digest'], r'^[a-f0-9]+$')
            self.assertEqual(len(item['digest']), 128 if item['algorithm'] == 'sha512' else 64)
            self.assertNotIn('/latest/', item['url'])


if __name__ == '__main__':
    unittest.main()
