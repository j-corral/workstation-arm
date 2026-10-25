#!/usr/bin/env python3
"""Reconcile the managed local resolver without discarding user rules."""
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
managed = (
    dns.get('upstream_dns') in (
        ['tls://dns.quad9.net'],
        ['tls://security.cloudflare-dns.com'],
    )
    and not dns.get('fallback_dns')
)
if managed:
    changed = False
    if dns.get('upstream_dns') == ['tls://dns.quad9.net']:
        dns['upstream_dns'] = ['tls://security.cloudflare-dns.com']
        dns['bootstrap_dns'] = ['1.1.1.1', '1.0.0.1']
        dns['enable_dnssec'] = True
        changed = True
    # Query log enablement is security policy for this local resolver. AdGuard
    # may rewrite its dormant file preference, but must never reactivate the
    # actual query log on a later bootstrap run.
    querylog = config.setdefault('querylog', {})
    if querylog.get('enabled') is not False:
        querylog['enabled'] = False
        changed = True
    if changed:
        path.write_text(yaml.safe_dump(config, sort_keys=False))
