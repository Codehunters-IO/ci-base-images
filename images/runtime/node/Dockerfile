# syntax=docker/dockerfile:1.7
# ci-base-images (Node runtime) — base for Node/NestJS service images.
# Contents: Node 20 (Alpine/musl), tini, CA certificates, tzdata.
# Usage: FROM ghcr.io/codehunters-io/ci-base-images:X.Y.Z-node-runtime

FROM node:20.20.2-alpine@sha256:fb4cd12c85ee03686f6af5362a0b0d56d50c58a04632e6c0fb8363f609372293

# No build-base and no python3. A dependency that needs node-gyp compiles in the
# builder stage; shipping a C toolchain in the image that faces traffic hands an
# attacker a compiler.
# Two upgrades, two different problems.
#
# apk upgrade: the upstream tag lags its Alpine branch between rebuilds.
#
# npm@11: Node 20 bundles npm 10.8.2, whose own node_modules carry twenty
# fixable HIGH advisories (brace-expansion, cross-spawn, glob, ip-address,
# minimatch and friends). They are not the app's dependencies — they ship
# inside npm itself — so no lockfile in any consumer can fix them. npm@11 and
# not npm@latest: npm 12 requires node ^22.22.2, and the Node major here is
# the contract. Floating within 11.x is deliberate, same trade as apk upgrade.
#
# Together: 24 fixable CRITICAL/HIGH -> 0.
RUN set -eux; \
    apk upgrade --no-cache; \
    apk add --no-cache tini tzdata ca-certificates; \
    npm install -g npm@11; \
    npm cache clean --force; \
    rm -rf /root/.npm /tmp/*; \
    mkdir -p /app; \
    chown node:node /app

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    NODE_ENV=production \
    NPM_CONFIG_UPDATE_NOTIFIER=false

WORKDIR /app
# uid 1000, shipped by the upstream image. Reused rather than replaced so files
# copied --from a node builder stage keep their ownership.
USER node

# Node does not reap orphaned children either, and `npm start` style entrypoints
# put a shell between PID 1 and the process that should receive SIGTERM.
ENTRYPOINT ["/sbin/tini", "--"]

LABEL org.opencontainers.image.title="ci-base-images (node runtime)" \
      org.opencontainers.image.description="Runtime base for Node/NestJS services (Node 20, non-root, tini, no compiler)" \
      org.opencontainers.image.source="https://github.com/Codehunters-IO/ci-base-images" \
      org.opencontainers.image.vendor="codehunters" \
      org.opencontainers.image.licenses="MIT" \
      io.codehunters.usage="runtime" \
      io.codehunters.variant="node-runtime" \
      io.codehunters.contents.node="20" \
      io.codehunters.contents.libc="musl" \
      io.codehunters.contents.base="node:20.20.2-alpine" \
      io.codehunters.runs-as="node"
