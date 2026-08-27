#!/usr/bin/env bash
# Verifier — confirms `native-image` is on PATH and reports its version.
#
# native-image cannot be installed after the fact: `gu` was removed in GraalVM
# 23.x / JDK 21+, and the replacement is a separate base image that already
# carries the tool (`native-image-community`, not `jdk-community`). So this
# script only validates the binary is present, and fails fast if a future base
# image drops it or moves it off PATH.
set -euo pipefail

if ! command -v native-image >/dev/null 2>&1; then
    echo "native-image NOT found on PATH (expected on GraalVM variant)." >&2
    echo "JAVA_HOME=${JAVA_HOME:-unset}" >&2
    [ -n "${JAVA_HOME:-}" ] && ls -la "${JAVA_HOME}/bin" >&2 || true
    exit 1
fi

native-image --version
echo "native-image present and working."
