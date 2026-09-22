#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
: "${WS_ROOT:?}" "${WS_REPORT:?}"
WS_MODULE=$1
# shellcheck source=lib/common.sh
source "$WS_ROOT/lib/common.sh"
WS_TMP=$(mktemp -d)
export WS_TMP
trap 'rm -rf -- "$WS_TMP"' EXIT
trap 'log ERROR "Component stopped at line $LINENO (exit $?)."' ERR
# Only bootstrap supplies module names; this is an internal entry point.
# shellcheck disable=SC1090
source "$WS_ROOT/install/$WS_MODULE"
"$2"
