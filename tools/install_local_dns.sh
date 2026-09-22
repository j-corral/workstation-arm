#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
mode=${1:-}
root=${2:-}
binary=${3:-}
backup=${2:-}
files=(/etc/resolv.conf /etc/systemd/resolved.conf.d/60-workstation-quad9.conf /etc/systemd/resolved.conf.d/70-workstation-adguard.conf /etc/workstation-adguard/AdGuardHome.yaml /etc/systemd/system/AdGuardHome.service /opt/workstation-adguard/AdGuardHome /etc/docker/daemon.json)
report() { printf '%s\n' "$*" >&2; }
restore() {
    local index=0 path
    [[ -d $backup && -f $backup/manifest ]] || { report 'Backup manifest missing.'; return 1; }
    systemctl stop AdGuardHome.service 2>/dev/null || true
    while IFS= read -r path; do
        if [[ -f $backup/$index.file ]]; then
            if [[ $path == /etc/resolv.conf && -f $backup/$index.link ]]; then
                rm -f -- "$path"
                ln -s -- "$(cat "$backup/$index.link")" "$path"
            else
                install -d -m 0755 "$(dirname "$path")"
                cp -p -- "$backup/$index.file" "$path"
            fi
        elif [[ -f $backup/$index.absent ]]; then
            rm -f -- "$path"
        else
            report "Incomplete backup for $path"; return 1
        fi
        index=$((index+1))
    done < "$backup/manifest"
    systemctl daemon-reload
    systemctl restart systemd-resolved.service
    if [[ -f $backup/adguard.enabled ]]; then systemctl enable AdGuardHome.service; else systemctl disable AdGuardHome.service 2>/dev/null || true; fi
    if [[ -f $backup/adguard.active ]]; then systemctl start AdGuardHome.service; fi
    if [[ -f $backup/docker.active ]]; then systemctl restart docker.service; fi
    report "DNS restored from $backup"
}
if [[ $mode == rollback ]]; then restore; exit; fi
[[ $mode == install && -n $root && -f $binary && $EUID == 0 ]] || { report 'Usage: sudo install_local_dns.sh install ROOT ARM64_BINARY, or rollback BACKUP'; exit 2; }
[[ $(uname -m) == aarch64 && $(dpkg --print-architecture) == arm64 ]] || { report 'Native ARM64 required.'; exit 1; }
# shellcheck disable=SC1091
source /etc/os-release
[[ $ID == ubuntu && $VERSION_ID == 26.04 ]] || { report 'Ubuntu 26.04 required.'; exit 1; }
command -v dig >/dev/null && command -v ss >/dev/null && command -v ip >/dev/null
systemctl is-active --quiet systemd-resolved.service || { report 'systemd-resolved must be active.'; exit 1; }
[[ -L /etc/resolv.conf && $(readlink -f /etc/resolv.conf) == /run/systemd/resolve/stub-resolv.conf ]] || { report 'Unexpected /etc/resolv.conf; expected systemd-resolved stub symlink. No changes made.'; exit 1; }
for path in /etc/systemd/resolved.conf.d/60-workstation-quad9.conf /etc/systemd/resolved.conf.d/70-workstation-adguard.conf /etc/workstation-adguard/AdGuardHome.yaml /etc/systemd/system/AdGuardHome.service /opt/workstation-adguard/AdGuardHome /etc/docker/daemon.json; do
    [[ ! -L $path ]] || { report "Refusing symlinked managed path: $path"; exit 1; }
done
if [[ -e /etc/systemd/resolved.conf.d/60-workstation-quad9.conf ]] && ! cmp -s "$root/config/quad9-resolved.conf" /etc/systemd/resolved.conf.d/60-workstation-quad9.conf; then report 'Existing Quad9 config differs; reconcile manually.'; exit 1; fi
if [[ -e /etc/systemd/resolved.conf.d/70-workstation-adguard.conf ]] && ! cmp -s "$root/config/adguard-resolved.conf" /etc/systemd/resolved.conf.d/70-workstation-adguard.conf; then report 'Existing AdGuard resolver config differs; reconcile manually.'; exit 1; fi
if [[ -e /etc/systemd/system/AdGuardHome.service ]] && ! cmp -s "$root/config/adguard-home.service" /etc/systemd/system/AdGuardHome.service; then report 'Existing AdGuardHome service is unmanaged; refusing overwrite.'; exit 1; fi
for path in /etc/systemd/resolved.conf /etc/systemd/resolved.conf.d/*.conf; do
    [[ -f $path && $path != /etc/systemd/resolved.conf.d/60-workstation-quad9.conf && $path != /etc/systemd/resolved.conf.d/70-workstation-adguard.conf ]] || continue
    if grep -Eq '^[[:space:]]*(DNS|FallbackDNS|Domains|DNSStubListener)[[:space:]]*=' "$path"; then report "Conflicting resolver setting in $path; review before install."; exit 1; fi
done
listener=$(ss -H -lunpt '( sport = :53 )' 2>/dev/null || true)
if [[ -n $listener ]] && grep -v 'systemd-resolv\|AdGuardHome' <<< "$listener" | grep -q .; then report "Unexpected port 53 listener: $listener"; exit 1; fi
report "Preflight: $(uname -m), Ubuntu $VERSION_ID; resolved active; resolv.conf -> $(readlink /etc/resolv.conf)"
report "Port 53: ${listener:-none}; NetworkManager: $(systemctl is-active NetworkManager.service 2>/dev/null || true)"
report "Interfaces: $(ip -br link | tr '\n' ' ')"
docker_active=0
gateway=''
if systemctl is-active --quiet docker.service; then
    docker_active=1
    docker --host unix:///var/run/docker.sock info >/dev/null
    gateway=$(ip -4 -o addr show dev docker0 2>/dev/null | awk 'NR==1 {split($4,a,"/"); print a[1]}')
    [[ -n $gateway ]] || { report 'Docker active but docker0 gateway absent; refusing to guess container DNS.'; exit 1; }
    [[ -z $(docker --host unix:///var/run/docker.sock ps -q) ]] || { report 'Running containers detected; stop them before changing daemon DNS.'; exit 1; }
    if [[ -e /etc/docker/daemon.json ]]; then
        python3 - /etc/docker/daemon.json "$gateway" <<'PY'
import json, sys
v = json.load(open(sys.argv[1]))
if not isinstance(v, dict) or ('dns' in v and v['dns'] != [sys.argv[2]]):
    raise SystemExit('Existing Docker DNS is unmanaged; refusing overwrite.')
PY
    fi
fi
# Snapshot every touched path, including the unchanged resolver symlink, before mutation.
backup=/var/lib/workstation/dns-backups/$(date -u +%Y%m%dT%H%M%SZ)-$$
install -d -m 0700 "$backup"
printf '%s\n' "${files[@]}" > "$backup/manifest"
for index in "${!files[@]}"; do
    path=${files[$index]}
    if [[ -L $path ]]; then
        printf '%s\n' "$(readlink "$path")" > "$backup/$index.link"
        cp -pL -- "$path" "$backup/$index.file"
    elif [[ -e $path ]]; then cp -p -- "$path" "$backup/$index.file"
    else : > "$backup/$index.absent"; fi
done
if systemctl is-active --quiet AdGuardHome.service; then : > "$backup/adguard.active"; fi
if systemctl is-enabled --quiet AdGuardHome.service; then : > "$backup/adguard.enabled"; fi
if (( docker_active )); then : > "$backup/docker.active"; fi
committed=0
on_exit() { local rc=$?; if (( ! committed )); then report 'Install failed; restoring saved DNS state.'; restore || true; fi; exit "$rc"; }
trap on_exit EXIT
if ! id workstation-adguard >/dev/null 2>&1; then useradd --system --no-create-home --home-dir /var/lib/workstation-adguard --shell /usr/sbin/nologin workstation-adguard; fi
install -d -m 0755 /opt/workstation-adguard
# AdGuard saves configuration atomically beside the YAML file.  The dedicated
# configuration directory must therefore be writable by its service account.
install -d -m 0750 -o workstation-adguard -g workstation-adguard /etc/workstation-adguard
install -d -m 0700 -o workstation-adguard -g workstation-adguard /var/lib/workstation-adguard
if [[ ! -e /opt/workstation-adguard/AdGuardHome ]] || ! cmp -s "$binary" /opt/workstation-adguard/AdGuardHome; then
    systemctl stop AdGuardHome.service 2>/dev/null || true
    install -m 0755 "$binary" /opt/workstation-adguard/AdGuardHome
fi
if [[ ! -e /etc/workstation-adguard/AdGuardHome.yaml ]]; then
    cp "$root/config/adguard-home.yaml" /etc/workstation-adguard/AdGuardHome.yaml
    if (( docker_active )); then sed -i "/^  - 127.0.0.1$/a\\  - $gateway" /etc/workstation-adguard/AdGuardHome.yaml; fi
    chmod 0640 /etc/workstation-adguard/AdGuardHome.yaml
    chown workstation-adguard:workstation-adguard /etc/workstation-adguard/AdGuardHome.yaml
else
    # Preserve existing rules, but never silently retain insecure upstreams/fallbacks.
    python3 "$root/tools/check_adguard_config.py" /etc/workstation-adguard/AdGuardHome.yaml "$gateway"
fi
python3 "$root/tools/check_adguard_config.py" /etc/workstation-adguard/AdGuardHome.yaml "$gateway"
/opt/workstation-adguard/AdGuardHome --check-config -c /etc/workstation-adguard/AdGuardHome.yaml -w /var/lib/workstation-adguard
install -m 0644 "$root/config/adguard-home.service" /etc/systemd/system/AdGuardHome.service
install -d -m 0755 /etc/systemd/resolved.conf.d
rm -f /etc/systemd/resolved.conf.d/60-workstation-quad9.conf
install -m 0644 "$root/config/adguard-resolved.conf" /etc/systemd/resolved.conf.d/70-workstation-adguard.conf
if (( docker_active )); then
    install -d -m 0755 /etc/docker
    python3 - /etc/docker/daemon.json "$gateway" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); value = json.loads(p.read_text()) if p.exists() else {}
value['dns'] = [sys.argv[2]]
p.write_text(json.dumps(value, indent=2) + '\n')
p.chmod(0o644)
PY
fi
systemctl daemon-reload
systemctl enable --now AdGuardHome.service
systemctl restart systemd-resolved.service
if (( docker_active )); then systemctl restart docker.service; fi
bash "$root/tools/dns_status.sh" --test "$gateway"
committed=1
trap - EXIT
report "DNS installed. Offline rollback: sudo bash $root/tools/install_local_dns.sh rollback '$backup'"
