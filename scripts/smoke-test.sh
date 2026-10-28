#!/usr/bin/env bash
# Smoke test — asserts every required tool resolves and reports expected versions.
# Invoked at image build time and as a CI gate before pushing to GHCR.
#
# CI_VARIANT controls variant-specific assertions:
#   jdk     (default) — Temurin JDK + Gradle + AWS CLI + Docker
#   graalvm           — GraalVM CE + native-image (everything in jdk +)
#   krakend           — KrakenD CLI + Go toolchain + make (no JDK/Gradle)
#   node              — Node 20 + npm + corepack + node-gyp deps (no JDK/Gradle)
#
# CI_JAVA_MAJOR, on the Java variants, is the major the image claims to carry.
# The repository now publishes two of them side by side, from directories that
# are near-identical copies; a FROM edited in one and a label edited in the
# other is the likeliest way this breaks, and check-pins.sh cannot see it
# because both files stay internally consistent. So the running JVM is asked.
#
# The krakend variant is asked two questions of the same shape, and for the same
# reason — a static check reads what a file claims, these read what the image can
# actually do: whether the KrakenD binary still carries the subcommands that
# build and load Go plugins (CE 3.0 dropped them), and whether the Go toolchain
# beside it is the one that binary was built with (a plugin loads into nothing
# else). Both are the difference between a plugin that loads and one that
# compiles, ships and silently never loads.
set -euo pipefail

CI_VARIANT="${CI_VARIANT:-jdk}"
CI_JAVA_MAJOR="${CI_JAVA_MAJOR:-}"

echo "=== Smoke test: ci-base-images (variant=${CI_VARIANT}) ==="

fail=0
check() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf "  [OK]   %s\n" "${label}"
    else
        printf "  [FAIL] %s\n" "${label}"
        fail=1
    fi
}

# `java -version` writes to stderr and reports the major as the leading
# component of the version string: "25.0.1" on a release, "25-ea" on an EA
# build, and a bare "25" is legal too. The version line is matched wherever it
# lands rather than taken as line 1 — a set JAVA_TOOL_OPTIONS makes the JVM
# print a "Picked up" line ahead of the banner.
check_java_major() {
    local want="$1" got
    got=$(java -version 2>&1 | sed -n 's/.*version "\([0-9]*\).*/\1/p' | sed -n 1p)
    if [ -z "${want}" ]; then
        printf "  [FAIL] java major: CI_JAVA_MAJOR is unset in this image\n"
        fail=1
    elif [ "${got}" = "${want}" ]; then
        printf "  [OK]   java major %s matches CI_JAVA_MAJOR\n" "${got}"
    else
        printf "  [FAIL] java major: image claims %s, JVM reports %s\n" "${want}" "${got:-unknown}"
        fail=1
    fi
}

# KrakenD CE 3.0 removed Go plugin loading, and building plugins is the only
# reason this variant exists. Nothing that reads a version string can see the
# removal: measured 2026-10-28, krakend:3.0.1 accepts the `plugin` and
# `plugin/http-server` config blocks and answers "Syntax OK!" exactly as 2.x
# does, while running no plugin loader at all. What it no longer carries are the
# two subcommands that build and load plugins — `check-plugin --help` and
# `test-plugin --help` exit 0 on krakend:2.13.11 and 255 on krakend:3.0.1, and
# `krakend help` lists neither. So the binary is asked whether it can still load
# a plugin rather than asked its version: a pin, a label and a FROM that all
# agree on a major without the capability still fail here. That is what the
# 2.0.0 release needed and did not have.
check_krakend_plugin_support() {
    local sub
    for sub in check-plugin test-plugin; do
        if krakend "${sub}" --help >/dev/null 2>&1; then
            printf "  [OK]   krakend %s — this binary can load Go plugins\n" "${sub}"
        else
            printf "  [FAIL] krakend %s is gone: this binary cannot load Go plugins\n" "${sub}"
            fail=1
        fi
    done
}

# A Go plugin loads only into a binary built by the same Go toolchain, so
# GO_VERSION is not a free choice — it has to equal the toolchain the pinned
# KrakenD release was built with. The Dockerfile says so and tells the reader to
# check it by hand with `go version -m`, and dependabot.yml ignores golang
# outright for the same reason, after it proposed 1.25.7 -> 1.27.1 against a
# KrakenD built on 1.26.8. Neither of those stops a hand edit, and check-pins.sh
# cannot see it: the ARG and the FROM agree whatever version they both name. The
# binary reports the toolchain it was built with, so the two are compared.
check_go_matches_krakend() {
    local want got
    want=$(krakend version 2>&1 | sed -n 's/^Go Version: *//p' | sed -n 1p)
    got=$(go version 2>&1 | sed -n 's/.*go\([0-9][0-9.]*\).*/\1/p' | sed -n 1p)
    if [ -z "${want}" ]; then
        printf "  [FAIL] go/krakend match: krakend reports no Go Version line\n"
        fail=1
    elif [ "${want}" = "${got}" ]; then
        printf "  [OK]   go %s matches the toolchain krakend was built with\n" "${got}"
    else
        printf "  [FAIL] go is %s but krakend was built with %s: plugins will not load\n" \
            "${got:-unknown}" "${want}"
        fail=1
    fi
}

# Common tooling shared by all variants.
check "aws"           aws --version
check "aws ecr help"  aws ecr help
check "docker"        docker --version
check "docker buildx" docker buildx version
check "jq"            jq --version
check "bc"            bc --version
check "curl"          curl --version
check "wget"          wget --version
check "git"           git --version
check "ssh"           ssh -V
check "bash"          bash --version
check "gawk"          gawk --version
check "gpg"           gpg --version

# Variant-specific tooling.
case "${CI_VARIANT}" in
    jdk)
        check "java"   java -version
        check "javac"  javac -version
        check "gradle" gradle --version
        check_java_major "${CI_JAVA_MAJOR}"
        ;;
    graalvm)
        check "java"         java -version
        check "javac"        javac -version
        check "gradle"       gradle --version
        check "native-image" native-image --version
        check_java_major "${CI_JAVA_MAJOR}"
        ;;
    krakend)
        check "krakend" krakend version
        check "go"      go version
        check "make"    make --version
        check_krakend_plugin_support
        check_go_matches_krakend
        ;;
    node)
        check "node"     node --version
        check "npm"      npm --version
        check "npx"      npx --version
        check "corepack" corepack --version
        # node-gyp fallback: a dependency without a linux-musl prebuild builds
        # from source at `npm ci`, and fails the whole pipeline without these.
        check "python3"  python3 --version
        check "cc"       cc --version
        check "make"     make --version
        ;;
    *)
        echo "  [FAIL] unknown CI_VARIANT=${CI_VARIANT}" >&2
        fail=1
        ;;
esac

echo ""
# `sed -n '1p'` and not `head -1`: head exits after the first line, the writer
# takes SIGPIPE, and `set -o pipefail` reports 141 for a version banner. sed
# reads to EOF, so the writer always gets to finish.
echo "Versions:"
aws --version 2>&1 | sed 's/^/  /'
docker --version | sed 's/^/  /'
case "${CI_VARIANT}" in
    jdk|graalvm)
        java -version 2>&1 | sed -n '1s/^/  /p'
        gradle --version 2>&1 | grep '^Gradle ' | sed 's/^/  /'
        ;;
esac
case "${CI_VARIANT}" in
    graalvm)
        native-image --version 2>&1 | sed -n '1s/^/  /p'
        ;;
    krakend)
        krakend version 2>&1 | sed -n '1s/^/  /p'
        go version | sed 's/^/  /'
        ;;
    node)
        node --version | sed 's/^/  node /'
        npm --version | sed 's/^/  npm /'
        ;;
esac

if [ "${fail}" -ne 0 ]; then
    echo ""
    echo "Smoke test FAILED."
    exit 1
fi

echo ""
echo "Smoke test PASSED."
