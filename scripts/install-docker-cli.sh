#!/bin/sh
# Dispatcher — selects Docker CLI install script by detected distro.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f /etc/alpine-release ]; then
    exec "${SCRIPT_DIR}/install-docker-cli-alpine.sh"
fi

if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}${ID_LIKE:-}" in
        *ol*|*rhel*|*fedora*|*centos*)
            exec "${SCRIPT_DIR}/install-docker-cli-ol.sh"
            ;;
    esac
fi

echo "Unsupported distro for docker-cli install dispatcher." >&2
exit 1
