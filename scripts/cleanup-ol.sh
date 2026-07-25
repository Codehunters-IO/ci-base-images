#!/usr/bin/env bash
# Final image cleanup (Oracle Linux 9) — remove caches and temp files to shrink layer.
set -euo pipefail

PM="microdnf"
if ! command -v "${PM}" >/dev/null 2>&1; then
    PM="dnf"
fi

"${PM}" clean all || true

rm -rf \
    /var/cache/dnf/* \
    /var/cache/yum/* \
    /var/cache/PackageKit/* \
    /tmp/* \
    /root/.cache \
    /root/.wget-hsts \
    /var/log/*

find / -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
find / -name '*.pyc' -delete 2>/dev/null || true

echo "Cleanup (Oracle Linux 9) complete."
