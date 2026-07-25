#!/bin/sh
# Final image cleanup (Alpine) — remove caches and temp files to shrink layer.
set -eu

rm -rf \
    /var/cache/apk/* \
    /tmp/* \
    /root/.cache \
    /root/.wget-hsts \
    /var/log/*

find / -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
find / -name '*.pyc' -delete 2>/dev/null || true

echo "Cleanup (Alpine) complete."
