#!/usr/bin/env bash
# Install AWS CLI v2 from official static bundle.
#
# Bundle is a glibc-linked PyInstaller binary. Behavior depends on libc:
#
#   musl (Alpine + gcompat shim): compatible with AWS CLI v2 <= 2.17.x (bundled
#     Python 3.11). v2.18+ bundles Python 3.14 which requires the `dladdr1`
#     glibc symbol that gcompat lacks. Pin to 2.17.65 on musl.
#
#   glibc (Oracle Linux 9 / GraalVM image): no shim needed. Default to the
#     latest published v2 release unless caller overrides AWS_CLI_VERSION.
#
# Integrity: downloaded over TLS from awscli.amazonaws.com. Optional GPG
# verification by setting AWS_CLI_VERIFY_GPG=1.
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
