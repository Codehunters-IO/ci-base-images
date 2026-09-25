#!/usr/bin/env bash
# Final image cleanup (Oracle Linux 9) — remove caches and temp files to shrink layer.
set -euo pipefail

PM="microdnf"
if ! command -v "${PM}" >/dev/null 2>&1; then
    PM="dnf"
fi

"${PM}" clean all || true

# Message catalogues for languages no CI log is ever read in. This runs at the
# end of every install layer, so what it removes is what that same layer just
# created - the base image's own catalogues are left alone, since deleting
# those would only add a whiteout. LANG is C.UTF-8 in every variant.
rm -rf /usr/share/locale/* 2>/dev/null || true

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
