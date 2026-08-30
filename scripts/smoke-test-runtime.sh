#!/usr/bin/env sh
# Smoke test for the runtime images — asserts what an application base owes its
# app, and asserts what it must NOT carry.
#
# sh, not bash: these images ship no bash, which is the point of them.
#
# RUNTIME_VARIANT selects the assertions:
#   java  — Temurin JRE 21, no javac
#   node  — Node 20, no compiler
#   web   — nginx, config valid, listens 8080
#
# The `native` variant has no shell and is asserted from the host instead.
set -eu

VARIANT="${RUNTIME_VARIANT:-java}"
echo "=== Runtime smoke test (variant=${VARIANT}) ==="

fail=0
check() {
    label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf "  [OK]   %s\n" "${label}"
    else
        printf "  [FAIL] %s\n" "${label}"
        fail=1
    fi
}

# A build tool in a runtime image is surface the app never asked for, so its
# absence is asserted rather than assumed.
refute() {
    label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf "  [FAIL] %s (present, must not be)\n" "${label}"
        fail=1
    else
        printf "  [OK]   %s absent\n" "${label}"
    fi
}

check "not running as root" sh -c '[ "$(id -u)" -ne 0 ]'
printf "  uid=%s gid=%s\n" "$(id -u)" "$(id -g)"

refute "docker CLI" command -v docker
refute "aws CLI"    command -v aws
refute "git"        command -v git

case "${VARIANT}" in
    java)
        check  "java"   java -version
        refute "javac"  command -v javac
        refute "jar"    command -v jar
        refute "gradle" command -v gradle
        check  "tini"   sh -c '[ -x /sbin/tini ]'
        java -version 2>&1 | grep -v 'Picked up' | sed -n '1s/^/  /p'
        ;;
    node)
        check  "node"  node --version
        check  "npm"   npm --version
        refute "cc"    command -v cc
        refute "make"  command -v make
        refute "python3" command -v python3
        check  "tini"  sh -c '[ -x /sbin/tini ]'
        printf "  node %s\n" "$(node --version)"
        ;;
    web)
        check  "nginx"        nginx -v
        check  "config valid" nginx -t
        check  "listens 8080" grep -q "listen  *8080" /etc/nginx/conf.d/default.conf
        check  "pid under /tmp" grep -q "pid /tmp/nginx.pid" /etc/nginx/nginx.conf
        check  "SPA fallback" grep -q "try_files .* /index.html" /etc/nginx/conf.d/default.conf
        nginx -v 2>&1 | sed -n '1s/^/  /p'
        ;;
    *)
        echo "  [FAIL] unknown RUNTIME_VARIANT=${VARIANT}" >&2
        fail=1
        ;;
esac

echo ""
if [ "${fail}" -ne 0 ]; then
    echo "Runtime smoke test FAILED." >&2
    exit 1
fi
echo "Runtime smoke test PASSED."
