# syntax=docker/dockerfile:1.7
# ci-base-images (Node variant) — pre-baked CI image for Hardhat/Solidity and
# TypeScript SDK pipelines (codehunters/tickets and friends).
# Contents: Node.js 20 (Alpine/musl), npm, corepack (pnpm/yarn on demand),
# node-gyp build deps, AWS CLI v2, Docker CLI + buildx.
# Usage: jobs.<id>.container: ghcr.io/codehunters/ci-base-images:vX.Y.Z-node

# Node 20 rather than 22: consumers pin it (`engines: ">=20 <21"`, `.nvmrc`),
# because the Hardhat toolchain and the pinned crypto dependencies are what
# decide bytes that get signed and anchored on chain. The image follows the
# consumers; it does not lead them.
ARG NODE_VERSION=20.20.2

FROM node:${NODE_VERSION}-alpine

# No default: BuildKit fills TARGETARCH with the platform being built, but only
# for an ARG declared without one. `ARG TARGETARCH=amd64` shadows it, and the
# arm64 build then downloads x86_64 artefacts.
ARG TARGETARCH
ARG NODE_VERSION=20.20.2
# AWS_CLI_VERSION only applies if AWS_CLI_FROM_BUNDLE=1 forces the glibc bundle;
# the musl path installs aws-cli from the Alpine community repo and ignores it.
# The pin is the last release that ran under gcompat, kept for that escape hatch.
ARG AWS_CLI_VERSION=2.17.65
ARG AWS_CLI_VERIFY_GPG=1

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    CI_VARIANT=node \
    # npm writes progress bars and funding notices nobody reads in a log file.
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_PROGRESS=false \
    PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin

COPY scripts/ /usr/local/bin/

RUN set -eux; \
    chmod +x /usr/local/bin/*.sh; \
    /usr/local/bin/install-base-packages.sh; \
    # node-gyp fallback path: a dependency without a linux-musl prebuild has to
    # compile here, and a CI image that cannot do that fails at `npm ci` in
    # every consumer at once. python3 + build-base is the price of that not
    # happening.
    apk add --no-cache \
        build-base \
        python3; \
    # npm 10.8.2, bundled with Node 20, carries a CRITICAL in its own vendored
    # tar (CVE-2026-59873). It sits in npm's node_modules, so no consumer
    # lockfile reaches it. npm@11 and not npm@latest: npm 12 wants node
    # ^22.22.2, and the Node major here follows the consumers.
    npm install -g npm@11; \
    npm cache clean --force; \
    TARGETARCH="${TARGETARCH}" AWS_CLI_VERSION="${AWS_CLI_VERSION}" AWS_CLI_VERIFY_GPG="${AWS_CLI_VERIFY_GPG}" \
        /usr/local/bin/install-aws-cli.sh; \
    /usr/local/bin/install-docker-cli.sh; \
    /usr/local/bin/install-node-toolchain.sh; \
    /usr/local/bin/cleanup.sh; \
    /usr/local/bin/smoke-test.sh

LABEL org.opencontainers.image.title="ci-base-images" \
      org.opencontainers.image.description="CI base image for Hardhat/Solidity and TypeScript pipelines (Node 20, npm, corepack, node-gyp deps, AWS CLI v2, Docker CLI)" \
      org.opencontainers.image.source="https://github.com/codehunters/ci-base-images" \
      org.opencontainers.image.vendor="codehunters" \
      org.opencontainers.image.licenses="MIT" \
      io.codehunters.usage="ci-only" \
      io.codehunters.variant="node" \
      io.codehunters.contents.node="${NODE_VERSION}" \
      io.codehunters.contents.libc="musl" \
      io.codehunters.contents.base="node:${NODE_VERSION}-alpine"

WORKDIR /workspace
ENTRYPOINT []
CMD ["/bin/bash"]
