#!/bin/sh
# Install base apk packages required by CI workflows (Alpine/musl variant).
# Runs under /bin/sh (ash) — bash is installed here.
#
# mandoc is not decoration: the apk build of the AWS CLI renders `aws <cmd> help`
# through a system pager rather than bundling its own docs, so without it every
# `aws ... help` reports "Could not find executable named groff or mandoc".
set -eu

# Upgrade first: the upstream tags (eclipse-temurin, node, alpine) are rebuilt
# on their own cadence and lag their Alpine branch in between, so a digest pin
# freezes whatever openssl or expat they shipped with. The runtime images have
# done this from the start; the CI ones did not, and the weekly rescan of the
# published 1.3.2 tags found the gap: fixable HIGH in libexpat and openssl on
# jdk, jdk25 and node, all from the base, none from anything installed here.
apk upgrade --no-cache

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
    tzdata \
    gnupg \
    mandoc

for bin in bash jq curl wget git ssh awk sed grep cut bc gpg; do
    command -v "$bin" >/dev/null 2>&1 || { echo "Missing: $bin" >&2; exit 1; }
done

echo "Base packages (Alpine) installed."
