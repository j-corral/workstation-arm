#!/usr/bin/env python3
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / 'config/adguard-home.yaml'
CHECKER = ROOT / 'tools/check_adguard_config.py'


class LocalDnsTests(unittest.TestCase):
    def check(self, config, gateway=''):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'AdGuardHome.yaml'
            path.write_text(yaml.safe_dump(config))
            return subprocess.run(['python3', str(CHECKER), str(path), gateway], capture_output=True, text=True)

    def test_secure_initial_configuration(self):
        config = yaml.safe_load(TEMPLATE.read_text())
        self.assertEqual(self.check(config).returncode, 0)
        self.assertEqual(config['schema_version'], 34)
        self.assertEqual(json.loads((ROOT / 'config/downloads.json').read_text())['adguard_home']['version'], 'v0.107.79')
        self.assertIn('DNS=127.0.0.1', (ROOT / 'config/adguard-resolved.conf').read_text())
        self.assertIn('Domains=~.', (ROOT / 'config/adguard-resolved.conf').read_text())

    def test_existing_rules_preserved_but_insecure_upstream_rejected(self):
        config = yaml.safe_load(TEMPLATE.read_text())
        config['user_rules'] = ['@@||client.example^']
        self.assertEqual(self.check(config).returncode, 0)
        for key, value in [('upstream_dns', ['9.9.9.9']), ('fallback_dns', ['1.1.1.1']), ('bind_hosts', ['0.0.0.0'])]:
            altered = copy.deepcopy(config)
            altered['dns'][key] = value
            self.assertNotEqual(self.check(altered).returncode, 0, key)

    def test_docker_listener_requires_exact_gateway(self):
        config = yaml.safe_load(TEMPLATE.read_text())
        config['dns']['bind_hosts'].append('172.17.0.1')
        self.assertEqual(self.check(config, '172.17.0.1').returncode, 0)
        self.assertNotEqual(self.check(config, '172.18.0.1').returncode, 0)

    def test_dns_diagnostic_waits_for_new_service(self):
        script = (ROOT / 'tools/dns_status.sh').read_text()
        self.assertIn('ready<15', script)
        self.assertLess(script.index('ready<15'), script.index('systemctl is-active --quiet AdGuardHome.service'))
