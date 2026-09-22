#!/usr/bin/env bash
# Logs contain our status messages only, never authentication output or shell traces.
log() {
    local line
    line="$(date -u '+%Y-%m-%dT%H:%M:%SZ') [$1] $2"
    printf '%s\n' "$line"
    if [[ -n ${WS_REPORT:-} ]]; then printf '%s\n' "$line" >> "$WS_REPORT/events.log"; fi
}
record() {
    log "$1" "$2: $3"
    if [[ -n ${WS_REPORT:-} ]]; then printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$WS_REPORT/results.tsv"; fi
}
manual() { record MANUAL "$1" "$2"; }
