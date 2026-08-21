#!/usr/bin/env bash
# Smoke test — asserts every required tool resolves and reports expected versions.
# Invoked at image build time and as a CI gate before pushing to GHCR.
#
# CI_VARIANT controls variant-specific assertions:
#   jdk     (default) — Temurin JDK 21 + Gradle + AWS CLI + Docker + WireGuard
#   graalvm           — GraalVM CE JDK 21 + native-image (everything in jdk +)
#   krakend           — KrakenD CLI + Go toolchain + make (no JDK/Gradle)
#   node              — Node 20 + npm + corepack + node-gyp deps (no JDK/Gradle)
set -euo pipefail

CI_VARIANT="${CI_VARIANT:-jdk}"

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

# Common tooling shared by all variants.
check "aws"           aws --version
check "aws ecr help"  aws ecr help
check "docker"        docker --version
check "docker buildx" docker buildx version
check "wg"            wg --version
check "wg-quick"      wg-quick --help
check "iptables"      iptables --version
check "ip"            ip -V
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
        ;;
    graalvm)
        check "java"         java -version
        check "javac"        javac -version
        check "gradle"       gradle --version
        check "native-image" native-image --version
        ;;
    krakend)
        check "krakend" krakend version
        check "go"      go version
        check "make"    make --version
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
echo "Versions:"
aws --version 2>&1 | sed 's/^/  /'
docker --version | sed 's/^/  /'
wg --version | sed 's/^/  /'
case "${CI_VARIANT}" in
    jdk|graalvm)
        java -version 2>&1 | head -1 | sed 's/^/  /'
        gradle --version 2>&1 | grep '^Gradle ' | sed 's/^/  /'
        ;;
esac
case "${CI_VARIANT}" in
    graalvm)
        native-image --version 2>&1 | head -1 | sed 's/^/  /'
        ;;
    krakend)
        krakend version 2>&1 | head -1 | sed 's/^/  /'
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
