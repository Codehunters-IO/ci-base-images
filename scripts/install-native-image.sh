#!/usr/bin/env bash
# Verifier — confirms `native-image` is on PATH and reports its version.
#
# GraalVM for JDK 21 ships native-image preinstalled (the `gu` component
# installer was removed in GraalVM 23.x / JDK 21+ distributions). This script
# only validates the binary is present and fails fast if the base image
# unexpectedly drops native-image in a future release.
set -euo pipefail

if ! command -v native-image >/dev/null 2>&1; then
    echo "native-image NOT found on PATH (expected on GraalVM variant)." >&2
    echo "JAVA_HOME=${JAVA_HOME:-unset}" >&2
    [ -n "${JAVA_HOME:-}" ] && ls -la "${JAVA_HOME}/bin" >&2 || true
    exit 1
fi

native-image --version
echo "native-image present and working."
