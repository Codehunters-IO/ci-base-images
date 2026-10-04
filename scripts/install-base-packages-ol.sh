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
# --nodocs and no weak dependencies. Measured on the published graalvm image:
# our own layer carried 20.7 MB of /usr/share/doc, 3.9 MB of man pages and
# 19.4 MB of perl, the last of which arrives only as a weak dependency of
# git. Nothing in a CI job reads a man page. Prevention rather than a later
# `rm`: a deletion in a subsequent layer writes a whiteout and the bytes
# still ship.

# OL_UPGRADE=1 upgrades the base before installing. The GraalVM CE images are
# not rebuilt on the Oracle Linux errata cadence, so the packages they carry
# age in place: the published graalvm (JDK 21, OL 9.3) image had 887 fixable
# HIGH findings in glibc, gnutls, libxml2, krb5 and friends, none from anything
# we install. Pinning the base by digest keeps the build reproducible; this
# keeps it patched.
#
# Opt-in per Dockerfile because it is not free: an upgraded package is written
# again in this layer while the old copy still ships in the base layer below,
# ~90 MB here. The JDK 25 base is fresh enough that it buys no HIGH there.
#
# codeready_builder only for this step: native-image needs glibc-static and
# libstdc++-static, which live there and pin glibc/libstdc++ to their exact
# version. With the repo disabled the upgrade cannot move them and refuses to
# move glibc at all. The repo id is read rather than hardcoded (ol9_ on the
# JDK 21 base, ol10_ on the JDK 25 one) because microdnf fails on --enablerepo
# for an id it does not know.
if [ "${OL_UPGRADE:-0}" = "1" ]; then
    UPGRADE_REPOS=()
    CRB_REPO="$(sed -n 's/^\[\(ol[0-9]*_codeready_builder\)\]$/\1/p' /etc/yum.repos.d/*.repo | head -n1)"
    if [ -n "${CRB_REPO}" ]; then
        UPGRADE_REPOS=(--enablerepo="${CRB_REPO}")
    fi
    "${PM}" upgrade -y --nodocs --setopt=install_weak_deps=0 "${UPGRADE_REPOS[@]}"
fi

"${PM}" install -y --nodocs --setopt=install_weak_deps=0 \
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
    tzdata \
    gnupg2

"${PM}" clean all

for bin in bash jq curl wget git ssh awk sed grep cut bc gpg; do
    command -v "$bin" >/dev/null 2>&1 || { echo "Missing: $bin" >&2; exit 1; }
done

echo "Base packages (Oracle Linux 9) installed."
