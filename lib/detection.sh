#!/usr/bin/env bash
check_awk() {
    local rc
    if awk 'BEGIN { exit 0 }'; then
        return 0
    else
        rc=$?
        log ERROR "awk cannot run (exit $rc). Stop before sudo/APT; inspect: file -L /usr/bin/awk; readlink -f /usr/bin/awk. Rosetta being enabled does not prove this executable is native ARM64."
        return "$rc"
    fi
}
check_target() {
    [[ $(uname -s) == Linux && -r /etc/os-release ]] || { log ERROR 'Requires Ubuntu 26.04 ARM64.'; return 1; }
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 26.04 ]] || { log ERROR 'Requires Ubuntu 26.04 exactly.'; return 1; }
    [[ $(uname -m) == aarch64 && $(dpkg --print-architecture) == arm64 ]] || {
        log ERROR 'Requires native aarch64 kernel and arm64 dpkg; emulated amd64 is not supported.'; return 1;
    }
    if [[ $EUID == 0 ]]; then
        [[ -n ${WS_AS_USER:-} ]] || { log ERROR 'Root execution requires --as-user ACCOUNT.'; return 1; }
        return
    fi
    [[ -z ${WS_AS_USER:-} ]] || { log ERROR '--as-user must be launched from root.'; return 1; }
    [[ -d $HOME && -O $HOME ]] || { log ERROR 'HOME must belong to the invoking user.'; return 1; }
    [[ $(getent passwd "$(id -u)" | cut -d: -f6) == "$HOME" ]] || {
        log ERROR 'HOME differs from the account home; refusing ambiguous user installation.'; return 1;
    }
}
disk_report() {
    df -h /
    local available
    available=$(df -Pk / | awk 'NR==2 {print $4}')
    if (( available < 20 * 1024 * 1024 )); then
        log WARN 'Less than 20 GiB free on /. KDE, SDKs and Docker need headroom; this estimate excludes client data.'
    fi
}
check_connectivity() {
    # Ubuntu desktop normally provides Python even before curl is installed.
    # An HTTPS request checks DNS, TLS and connectivity without requiring ICMP.
    command -v python3 >/dev/null || { log ERROR 'Prerequisite missing: Ubuntu system python3.'; return 1; }
    python3 - <<'PY'
import urllib.request
with urllib.request.urlopen('https://ports.ubuntu.com/ubuntu-ports/dists/resolute/InRelease', timeout=20) as r:
    if r.status != 200 or not r.read(64).startswith(b'-----BEGIN PGP SIGNED MESSAGE-----'):
        raise SystemExit('Unexpected Ubuntu archive response')
PY
}
