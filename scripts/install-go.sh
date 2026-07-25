#!/usr/bin/env bash
# Verifier — confirms the Go toolchain is on PATH and reports its version.
#
# The Go toolchain is COPYed at build time from the official
# `golang:${GO_VERSION}-alpine` image via a multi-stage stage in the
# Dockerfile. Alpine ships older Go in apk; copying matches the exact version
# used by `krakend/builder` (1.25.x) to guarantee `-buildmode=plugin` ABI
# compatibility with `krakend/krakend` runtime images.
#
# Also verifies build-time deps required for Go plugins on Alpine:
#   build-base    → cc/ld/gcc-libs (needed by cgo + -buildmode=plugin)
#   binutils-gold → the gold linker; KrakenD plugin guides require it
set -euo pipefail

if ! command -v go >/dev/null 2>&1; then
    echo "go NOT found on PATH (expected on krakend variant)." >&2
    echo "PATH=${PATH}" >&2
    ls -la /usr/local/go/bin 2>&1 || true
    exit 1
fi

for bin in gcc ld ld.gold; do
    command -v "$bin" >/dev/null 2>&1 || { echo "Missing plugin-build dep: $bin" >&2; exit 1; }
done

go version
gcc --version | head -1
ld.gold --version | head -1
echo "Go toolchain + plugin build deps OK."
