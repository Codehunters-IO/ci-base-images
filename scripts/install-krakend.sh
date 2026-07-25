#!/usr/bin/env bash
# Verifier — confirms KrakenD CLI is on PATH and reports its version.
#
# The `krakend` binary is COPYed at build time from the official
# `krakend:${KRAKEND_VERSION}` image via a multi-stage stage in the
# Dockerfile (no apk package exists for KrakenD). This script only validates
# the binary is present and fails fast if the multi-stage COPY was skipped.
#
# Usage: invoked by images/krakend/Dockerfile after multi-stage COPY.
set -euo pipefail

if ! command -v krakend >/dev/null 2>&1; then
    echo "krakend NOT found on PATH (expected on krakend variant)." >&2
    echo "PATH=${PATH}" >&2
    ls -la /usr/local/bin/krakend /usr/bin/krakend 2>&1 || true
    exit 1
fi

krakend version
echo "KrakenD CLI present and working."
