#!/usr/bin/env bash
set -Eeuo pipefail
source_file=$1
target=/etc/systemd/resolved.conf.d/60-workstation-quad9.conf
changed=0
rollback() {
    if (( changed )); then
        sudo rm -f -- "$target"
        sudo systemctl restart systemd-resolved.service || true
    fi
}
trap rollback EXIT

[[ $(readlink -f /etc/resolv.conf) == /run/systemd/resolve/stub-resolv.conf ]] || {
    printf 'The system resolver is not the systemd-resolved stub; DNS configuration was not changed.\n' >&2
    exit 1
}
systemctl is-active --quiet systemd-resolved.service
command -v resolvectl >/dev/null
if [[ -e $target || -L $target ]]; then
    [[ ! -L $target ]] || { printf 'Refusing symlinked Quad9 configuration.\n' >&2; exit 1; }
    if cmp -s "$source_file" "$target"; then
        timeout 15 resolvectl query -t TXT proto.on.quad9.net | grep -Eq '(^|[^a-z])dot\.'
        exit 0
    fi
    printf 'Existing Quad9 configuration differs; reconcile it manually.\n' >&2
    exit 1
fi

sudo install -d -m 0755 /etc/systemd/resolved.conf.d
changed=1
sudo install -m 0644 "$source_file" "$target"
sudo systemctl restart systemd-resolved.service
resolvectl flush-caches
if ! timeout 15 resolvectl query -t TXT proto.on.quad9.net | grep -Eq '(^|[^a-z])dot\.'; then
    printf 'Quad9 did not confirm DNS-over-TLS; restoring previous DNS configuration.\n' >&2
    exit 1
fi
changed=0
