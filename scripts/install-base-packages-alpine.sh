#!/bin/sh
# Install base apk packages required by CI workflows (Alpine/musl variant).
# Runs under /bin/sh (ash) — bash is installed here.
set -eu

apk add --no-cache \
    bash \
    ca-certificates \
    gcompat \
    coreutils \
    findutils \
    grep \
    sed \
    gawk \
    tar \
    gzip \
    unzip \
    xz \
    bc \
    jq \
    curl \
    wget \
    git \
    openssh-client \
    iputils \
    iptables \
    iproute2 \
    wireguard-tools \
    tzdata \
    gnupg

for bin in bash jq curl wget git ssh awk sed grep cut bc gpg wg wg-quick; do
    command -v "$bin" >/dev/null 2>&1 || { echo "Missing: $bin" >&2; exit 1; }
done

echo "Base packages (Alpine) installed."
