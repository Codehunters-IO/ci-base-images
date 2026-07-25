#!/usr/bin/env bash
# Install base packages required by CI workflows (Oracle Linux 9 / glibc variant).
# Used by GraalVM image. Enables EPEL for wireguard-tools.
set -euo pipefail

# microdnf is preinstalled on Oracle Linux 9 minimal images.
PM="microdnf"
if ! command -v "${PM}" >/dev/null 2>&1; then
    PM="dnf"
fi

"${PM}" install -y \
    ca-certificates \
    coreutils \
    findutils \
    gawk \
    sed \
    grep \
    tar \
    gzip \
    unzip \
    xz \
    bc \
    jq \
    curl \
    wget \
    git \
    openssh-clients \
    iputils \
    iptables-nft \
    iproute \
    tzdata \
    gnupg2

# EPEL release RPM hosts wireguard-tools on OL9.
EPEL_RPM_URL="https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm"
"${PM}" install -y "${EPEL_RPM_URL}"
"${PM}" install -y wireguard-tools

"${PM}" clean all

for bin in bash jq curl wget git ssh awk sed grep cut bc gpg wg wg-quick; do
    command -v "$bin" >/dev/null 2>&1 || { echo "Missing: $bin" >&2; exit 1; }
done

echo "Base packages (Oracle Linux 9) installed."
