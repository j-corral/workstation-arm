#!/usr/bin/env bash
set -Eeuo pipefail
mode=${1:-status}
gateway=${2:-}
printf 'AdGuard Home: '; systemctl is-active AdGuardHome.service || true
printf 'systemd-resolved: '; systemctl is-active systemd-resolved.service || true
printf '/etc/resolv.conf: '; readlink -f /etc/resolv.conf || true
printf 'Port 53 listeners:\n'; ss -H -lunpt '( sport = :53 )' || true
printf 'Network interfaces:\n'; ip -br addr || true
printf 'VPN candidates:\n'; ip -br link | grep -Ei 'tun|tap|wg|tailscale|vpn|ppp' || true
printf 'Resolver default route:\n'; resolvectl domain || true
printf 'Docker daemon DNS: '; if [[ -f /etc/docker/daemon.json ]]; then python3 - <<'PY'
import json
v = json.load(open('/etc/docker/daemon.json'))
print(v.get('dns', '(unset)'))
PY
else printf '(unset)\n'; fi
printf 'AdGuard upstream: '; if [[ -r /etc/workstation-adguard/AdGuardHome.yaml ]]; then python3 - <<'PY'
import yaml
v = yaml.safe_load(open('/etc/workstation-adguard/AdGuardHome.yaml'))
print(v.get('dns', {}).get('upstream_dns', '(missing)'))
PY
else printf '(not readable)\n'; fi
printf 'Quad9 protocol: '; timeout 20 dig +time=4 +tries=1 +short TXT proto.on.quad9.net | tr -d '"' || true
[[ $mode == --test ]] || exit 0
systemctl is-active --quiet AdGuardHome.service
systemctl is-active --quiet systemd-resolved.service
listeners=$(ss -H -lunpt '( sport = :53 )')
grep -Eq '^udp .*AdGuardHome' <<< "$listeners"
grep -Eq '^tcp .*AdGuardHome' <<< "$listeners"
grep -Eq '^udp .*systemd-resolv' <<< "$listeners"
grep -Eq '^tcp .*systemd-resolv' <<< "$listeners"
for attempt in 1 2 3 4 5; do
    if timeout 15 dig +time=3 +tries=1 +short A example.com | grep -Eq '^[0-9]+\.'; then break; fi
    sleep 2
done
timeout 15 dig +time=3 +tries=1 +short A example.com | grep -Eq '^[0-9]+\.'
timeout 15 dig +time=3 +tries=1 +short TXT proto.on.quad9.net | tr -d '"' | grep -Eq '^dot\.?$'
timeout 15 dig +time=3 +tries=1 brokendnssec.net A | grep -q 'status: SERVFAIL'
blocked=$(timeout 15 dig +time=3 +tries=1 isitblocked.org A)
grep -q 'status: NXDOMAIN' <<< "$blocked"
grep -q 'AUTHORITY: 0' <<< "$blocked"
# The operator documents dnssec.works as a valid signed test zone.
timeout 15 dig +time=3 +tries=1 dnssec.works A | grep -q 'status: NOERROR'
# Filter updates may finish shortly after first start; do not claim success before a known ad host is blocked.
for ((attempt=1; attempt<=6; attempt++)); do
    if timeout 15 dig +time=3 +tries=1 doubleclick.net A | grep -Eq 'status: NXDOMAIN|^doubleclick.net\.[[:space:]]+[^[:space:]]+[[:space:]]+IN[[:space:]]+A[[:space:]]+0\.0\.0\.0'; then break; fi
    sleep 5
done
timeout 15 dig +time=3 +tries=1 doubleclick.net A | grep -Eq 'status: NXDOMAIN|^doubleclick.net\.[[:space:]]+[^[:space:]]+[[:space:]]+IN[[:space:]]+A[[:space:]]+0\.0\.0\.0'
if [[ -n $gateway ]]; then
    test_container="workstation-dns-container-$$"
    cleanup_container() { docker --host unix:///var/run/docker.sock rm -f "$test_container" >/dev/null 2>&1 || true; }
    trap cleanup_container EXIT
    timeout 180 docker --host unix:///var/run/docker.sock run --rm --name "$test_container" --platform linux/arm64 busybox:1.37 cat /etc/resolv.conf | grep -Fq "$gateway"
    timeout 180 docker --host unix:///var/run/docker.sock run --rm --name "$test_container" --platform linux/arm64 busybox:1.37 nslookup example.com | grep -q 'Address'
    test_network="workstation-dns-check-$$"
    docker --host unix:///var/run/docker.sock network create --driver bridge "$test_network" >/dev/null
    cleanup_docker() {
        cleanup_container
        docker --host unix:///var/run/docker.sock network rm "$test_network" >/dev/null 2>&1 || true
    }
    trap cleanup_docker EXIT
    timeout 60 docker --host unix:///var/run/docker.sock run --rm --name "$test_container" --platform linux/arm64 --network "$test_network" busybox:1.37 nslookup example.com | grep -q 'Address'
    cleanup_docker
    trap - EXIT
fi
printf 'DNS installation tests passed.\n'
