#!/bin/sh
# Dispatcher — selects base-package install script by detected distro.
# Alpine → install-base-packages-alpine.sh (apk)
# Oracle Linux / RHEL family → install-base-packages-ol.sh (microdnf)
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f /etc/alpine-release ]; then
    exec "${SCRIPT_DIR}/install-base-packages-alpine.sh"
fi

if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}${ID_LIKE:-}" in
        *ol*|*rhel*|*fedora*|*centos*)
            exec "${SCRIPT_DIR}/install-base-packages-ol.sh"
            ;;
    esac
fi

echo "Unsupported distro for base-package install dispatcher." >&2
[ -f /etc/os-release ] && cat /etc/os-release >&2
exit 1
