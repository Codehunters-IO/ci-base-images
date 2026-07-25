#!/bin/sh
# Dispatcher — selects cleanup script by detected distro.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f /etc/alpine-release ]; then
    exec "${SCRIPT_DIR}/cleanup-alpine.sh"
fi

if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}${ID_LIKE:-}" in
        *ol*|*rhel*|*fedora*|*centos*)
            exec "${SCRIPT_DIR}/cleanup-ol.sh"
            ;;
    esac
fi

echo "Unsupported distro for cleanup dispatcher." >&2
exit 1
