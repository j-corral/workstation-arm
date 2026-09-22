#!/usr/bin/env python3
"""Reject drift that would silently bypass the local Quad9-only DNS chain."""
import ipaddress
from pathlib import Path
import sys
import yaml

config = yaml.safe_load(Path(sys.argv[1]).read_text())
gateway = sys.argv[2] if len(sys.argv) > 2 else ''
dns = config.get('dns', {})
expected = ['127.0.0.1'] + ([gateway] if gateway else [])
checks = {
    'Current configuration schema': config.get('schema_version') == 25,
    'DNS listeners': dns.get('bind_hosts') == expected,
    'DNS port': dns.get('port') == 53,
    'Quad9 DoT only': dns.get('upstream_dns') == ['tls://dns.quad9.net'],
    'Secure bootstrap only': dns.get('bootstrap_dns') == ['9.9.9.9', '149.112.112.112'],
    'No fallback': not dns.get('fallback_dns') and not dns.get('upstream_dns_file'),
    'No ECS': dns.get('edns_client_subnet', {}).get('enabled') is False and dns.get('edns_client_subnet', {}).get('use_custom') is False,
    'No extra DNSSEC validation': dns.get('enable_dnssec') is False,
    'Private admin UI': config.get('http', {}).get('address') == '127.0.0.1:3000',
    'No query log': config.get('querylog', {}).get('enabled') is False and config.get('querylog', {}).get('file_enabled') is False,
    'No statistics': config.get('statistics', {}).get('enabled') is False,
    'Filtering enabled': config.get('filtering', {}).get('filtering_enabled') is True,
    'No client upstream bypass': all(not client.get('upstreams') for client in config.get('clients', {}).get('persistent', [])),
}
for host in dns.get('bind_hosts', []):
    if not ipaddress.ip_address(host).is_private:
        checks['Private listeners'] = False
for name, passed in checks.items():
    if not passed:
        raise SystemExit(f'Unsafe or unmanaged AdGuard Home configuration: {name}')
