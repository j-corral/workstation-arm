#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
while IFS= read -r script; do bash -n "$script"; done < <(find . -name '*.sh' -type f -print)
if command -v shellcheck >/dev/null; then
    shellcheck bootstrap.sh verify.sh lib/*.sh install/*.sh tests/run.sh
else
    printf 'ShellCheck unavailable: install it before accepting changes.\n' >&2
    exit 1
fi
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_*.py' -v
