#!/usr/bin/env bash
# Smoke test for the native runtime image, run from the HOST.
#
# That image has no shell, so nothing can be executed inside it — which is the
# property being shipped. The assertions are therefore about image config and
# contents, read with docker inspect and an export of the filesystem.
#
# Usage: IMAGE=cbi:rt-native scripts/smoke-test-native.sh
set -euo pipefail

IMAGE="${IMAGE:?set IMAGE to the tag under test}"
echo "=== Native runtime smoke test (${IMAGE}) ==="

fail=0
assert() {
    local label="$1" expected="$2" actual="$3"
    if [ "${expected}" = "${actual}" ]; then
        printf "  [OK]   %s = %s\n" "${label}" "${actual}"
    else
        printf "  [FAIL] %s: expected %s, got %s\n" "${label}" "${expected}" "${actual}"
        fail=1
    fi
}

cfg() { docker image inspect "${IMAGE}" --format "$1"; }

assert "User"     "nonroot" "$(cfg '{{.Config.User}}')"
assert "WorkingDir" "/app"  "$(cfg '{{.Config.WorkingDir}}')"
assert "usage label" "runtime" "$(cfg '{{index .Config.Labels "io.codehunters.usage"}}')"
assert "shell label" "none"    "$(cfg '{{index .Config.Labels "io.codehunters.contents.shell"}}')"

# Export rather than run: there is no shell to run anything with.
files="$(mktemp)"
cid="$(docker create "${IMAGE}" /nonexistent)"
docker export "${cid}" | tar -tf - > "${files}"
docker rm -f "${cid}" >/dev/null

# libz is the whole reason this image is not plain distroless/base: native-image
# links it dynamically and distroless does not ship it.
if grep -qE "(usr/)?lib/.*libz\.so\.1" "${files}"; then
    printf "  [OK]   libz.so.1 present\n"
else
    printf "  [FAIL] libz.so.1 missing — native binaries will not exec\n"
    fail=1
fi

for absent in "bin/sh" "bin/bash" "bin/busybox" "usr/bin/apt" "usr/bin/docker"; do
    if grep -qE "^${absent}$" "${files}"; then
        printf "  [FAIL] %s present, must not be\n" "${absent}"
        fail=1
    else
        printf "  [OK]   %s absent\n" "${absent}"
    fi
done

printf "  files in image: %s\n" "$(wc -l < "${files}" | tr -d ' ')"
rm -f "${files}"

echo ""
if [ "${fail}" -ne 0 ]; then
    echo "Native runtime smoke test FAILED." >&2
    exit 1
fi
echo "Native runtime smoke test PASSED."
