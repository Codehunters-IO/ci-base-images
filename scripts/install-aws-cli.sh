#!/usr/bin/env bash
# Install AWS CLI v2. Source depends on libc:
#
#   musl (Alpine): `apk add aws-cli` from the community repository — a real
#     musl build, no shim. Alpine has shipped v2 there since 3.20.
#
#     The previous approach — AWS's own bundle pinned to 2.17.65 under gcompat
#     — no longer runs on current Alpine. The bundle is a glibc PyInstaller
#     binary, and each gcompat release drifts further from what it needs:
#     `posix_fallocate64` on Alpine 3.23, `pthread_attr_setaffinity_np` on
#     3.24. Chasing one pin per Alpine release was never going to hold, and
#     the failure lands at image build time, in every musl variant at once.
#     Set AWS_CLI_FROM_BUNDLE=1 to force the old path anyway.
#
#   glibc (Oracle Linux 9 / GraalVM image): the official static bundle, no
#     shim needed. Defaults to the latest published v2 release unless the
#     caller overrides AWS_CLI_VERSION.
#
# Integrity: apk packages are signed by the Alpine builders and verified by
# apk itself; bundles are downloaded over TLS from awscli.amazonaws.com, with
# optional GPG verification by setting AWS_CLI_VERIFY_GPG=1.
set -euo pipefail

TARGETARCH="${TARGETARCH:-amd64}"
AWS_CLI_VERIFY_GPG="${AWS_CLI_VERIFY_GPG:-0}"

detect_libc() {
    if [ -f /etc/alpine-release ]; then
        echo "musl"
        return
    fi
    if ldd --version 2>&1 | head -1 | grep -qi musl; then
        echo "musl"
        return
    fi
    echo "glibc"
}

LIBC="$(detect_libc)"
AWS_CLI_FROM_BUNDLE="${AWS_CLI_FROM_BUNDLE:-0}"

if [ "${LIBC}" = "musl" ] && [ "${AWS_CLI_FROM_BUNDLE}" != "1" ]; then
    echo "Installing AWS CLI v2 from the Alpine community repository (musl native)..."
    apk add --no-cache aws-cli
    aws --version
    echo "AWS CLI installed from apk (libc=musl)."
    exit 0
fi

if [ -z "${AWS_CLI_VERSION:-}" ]; then
    case "${LIBC}" in
        musl)  AWS_CLI_VERSION="2.17.65" ;;
        glibc) AWS_CLI_VERSION="latest" ;;
    esac
fi

case "${TARGETARCH}" in
    amd64)  AWS_ARCH="x86_64" ;;
    arm64)  AWS_ARCH="aarch64" ;;
    *)      echo "Unsupported arch: ${TARGETARCH}" >&2; exit 1 ;;
esac

if [ "${AWS_CLI_VERSION}" = "latest" ]; then
    AWS_ZIP="awscli-exe-linux-${AWS_ARCH}.zip"
else
    AWS_ZIP="awscli-exe-linux-${AWS_ARCH}-${AWS_CLI_VERSION}.zip"
fi

BASE_URL="https://awscli.amazonaws.com"

cd /tmp

echo "Downloading ${AWS_ZIP} (libc=${LIBC}, version=${AWS_CLI_VERSION})..."
curl -fSL -o "awscliv2.zip" "${BASE_URL}/${AWS_ZIP}"

if [ "${AWS_CLI_VERIFY_GPG}" = "1" ]; then
    echo "Fetching AWS CLI Team PGP key and verifying signature..."
    curl -fSL -o "awscliv2.sig" "${BASE_URL}/${AWS_ZIP}.sig"
    curl -fSL -o "aws-cli-pgp.txt" "https://awscli.amazonaws.com/aws-cli-pgp.txt"
    gpg --import aws-cli-pgp.txt
    gpg --verify awscliv2.sig awscliv2.zip
    rm -f awscliv2.sig aws-cli-pgp.txt
fi

unzip -q awscliv2.zip
./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update

rm -rf aws awscliv2.zip

rm -rf /usr/local/aws-cli/v2/current/dist/awscli/examples
find /usr/local/aws-cli -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
find /usr/local/aws-cli -name '*.pyc' -delete 2>/dev/null || true

aws --version
echo "AWS CLI v${AWS_CLI_VERSION} installed for ${AWS_ARCH} (libc=${LIBC})."
