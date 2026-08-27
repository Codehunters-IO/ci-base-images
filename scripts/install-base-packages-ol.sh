#!/usr/bin/env bash
# Install base packages required by CI workflows (Oracle Linux 9 / glibc variant).
# Used by GraalVM image.
set -euo pipefail

# microdnf is preinstalled on Oracle Linux 9 minimal images.
PM="microdnf"
if ! command -v "${PM}" >/dev/null 2>&1; then
    PM="dnf"
fi

# No `coreutils`: OL9 minimal ships `coreutils-single`, which provides the same
# binaries from one multi-call executable and *conflicts* with the split
# package. Asking for `coreutils` makes microdnf try to swap them and it
# refuses — "cannot install the best candidate for the job". The verify loop
# below covers what we actually need from it.
"${PM}" install -y \
    ca-certificates \
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

"${PM}" clean all

for bin in bash jq curl wget git ssh awk sed grep cut bc gpg; do
    command -v "$bin" >/dev/null 2>&1 || { echo "Missing: $bin" >&2; exit 1; }
done

echo "Base packages (Oracle Linux 9) installed."
