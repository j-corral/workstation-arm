#!/usr/bin/env python3
"""Migrate only the previous managed Quad9 upstream to Cloudflare Security."""
from pathlib import Path
import sys

import yaml

path = Path(sys.argv[1])
config = yaml.safe_load(path.read_text())
dns = config.get('dns', {})
# AdGuard Home may have normalized the old managed bootstrap list after its
# first start.  The upstream is the security boundary, so migrate every
# single-upstream Quad9 configuration with no fallback while retaining filters
# and user rules.  Other upstreams still require an explicit administrator
# decision and are rejected by the checker.
old = dns.get('upstream_dns') == ['tls://dns.quad9.net'] and not dns.get('fallback_dns')
if old:
    dns['upstream_dns'] = ['tls://security.cloudflare-dns.com']
    dns['bootstrap_dns'] = ['1.1.1.1', '1.0.0.1']
    dns['enable_dnssec'] = True
    path.write_text(yaml.safe_dump(config, sort_keys=False))
