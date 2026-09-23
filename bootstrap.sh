#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
WS_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export WS_ROOT WS_DRY_RUN=0 WS_REPORT=''
# shellcheck source=lib/common.sh
source "$WS_ROOT/lib/common.sh"
# shellcheck source=lib/detection.sh
source "$WS_ROOT/lib/detection.sh"
modules=(system kde shell git runtimes docker dev desktop network security ai accounts)
files=(01-system.sh 02-kde.sh 03-shell.sh 04-git-ssh.sh 05-runtimes.sh 06-docker.sh 07-dev-tools.sh 08-desktop-apps.sh 09-network.sh 10-security.sh 11-ai.sh 12-accounts.sh)
only='' skip='' current=preflight
valid_module() {
    local candidate
    for candidate in "${modules[@]}"; do
        if [[ $1 == "$candidate" ]]; then return 0; fi
    done
    return 1
}
usage() {
    cat <<'HELP'
Usage: ./bootstrap.sh [--dry-run] [--only MODULE | --skip MODULE]
Modules: system kde shell git runtimes docker dev desktop network security ai accounts
One filter is allowed. Minimal transport dependencies are always installed.
Dry-run is an offline plan: no writes, sudo, downloads or target validation.
HELP
}
while (( $# )); do
    case $1 in
        --dry-run) WS_DRY_RUN=1; shift ;;
        --only|--skip)
            (( $# >= 2 )) || { usage; exit 2; }
            [[ -z $only && -z $skip ]] || { usage; exit 2; }
            valid_module "$2" || { usage; exit 2; }
            if [[ $1 == --only ]]; then only=$2; else skip=$2; fi
            shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done
if [[ $WS_DRY_RUN == 0 ]]; then
    check_target
    check_awk
    command -v sudo >/dev/null
    sudo -v
    command -v flock >/dev/null
    state="${XDG_STATE_HOME:-$HOME/.local/state}/workstation"
    mkdir -p "$state"
    chmod 0700 "$state"
    exec 9> "$state/bootstrap.lock"
    flock -n 9 || { log ERROR 'Another bootstrap is running.'; exit 1; }
    WS_REPORT=$(mktemp -d "$state/run-$(date -u '+%Y%m%dT%H%M%SZ')-XXXXXX")
    export WS_REPORT
    : > "$WS_REPORT/results.tsv"
fi
finish() {
    local rc=$? heading title remaining
    trap - EXIT
    if [[ $WS_DRY_RUN == 0 ]]; then
        if (( rc != 0 )) && ! grep -q '^FAILED' "$WS_REPORT/results.tsv"; then
            record FAILED "$current" "Stopped (exit $rc); later modules were not attempted."
        fi
        if (( rc != 0 )); then
            for (( remaining=${index:--1}+1; remaining<${#modules[@]}; remaining++ )); do
                record SKIPPED "${modules[$remaining]}" 'Not attempted after a critical stop.'
            done
        fi
        printf '\nInstallation summary (this run)\n'
        for heading in INSTALLED SKIPPED MANUAL FAILED; do
            case $heading in
                INSTALLED) title=Installed ;;
                SKIPPED) title=Skipped ;;
                MANUAL) title='Manual action required' ;;
                FAILED) title=Failed ;;
            esac
            printf '\n%s\n' "$title"
            awk -F '\t' -v category="$heading" '$1==category { print "  - " $2 ": " $3; n++ } END {if (!n) print "  (none)"}' "$WS_REPORT/results.tsv"
        done
        if [[ -f /var/run/reboot-required ]]; then printf '\nReboot required: yes\n'; else printf '\nReboot required: no system flag; log out for shell/session changes\n'; fi
        disk_report
        dpkg-query -W -f='${binary:Package}\t${Version}\t${Architecture}\n' > "$WS_REPORT/packages.tsv"
        printf '\nReport: %s\n' "$WS_REPORT"
        cat "$WS_ROOT/docs/post-install.md"
    else
        printf '\nDry-run complete. Nothing installed; target/package availability not validated.\n'
    fi
    exit "$rc"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if [[ $WS_DRY_RUN == 0 ]]; then
    disk_report
    check_connectivity
    apt_update
    apt_install ca-certificates curl gnupg python3 unzip xz-utils tar file
else
    log PLANNED 'Preflight: Ubuntu 26.04/aarch64, sudo, HTTPS connectivity, disk; apt update; minimal transport dependencies.'
fi
for index in "${!modules[@]}"; do
    current=${modules[$index]}
    if [[ -n $only && $current != "$only" || $current == "$skip" ]]; then
        record SKIPPED "$current" 'Excluded by command-line filter.'
        continue
    fi
    WS_MODULE=${files[$index]}
    export WS_MODULE
    # shellcheck disable=SC1090
    source "$WS_ROOT/install/$WS_MODULE"
    main
    unset -f main
done
if [[ $WS_DRY_RUN == 0 ]] && grep -q '^FAILED' "$WS_REPORT/results.tsv"; then exit 1; fi
