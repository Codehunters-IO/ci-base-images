# syntax=docker/dockerfile:1.7
# ci-base-images (Node runtime) — base for Node/NestJS service images.
# Contents: Node 20 (Alpine/musl), tini, CA certificates, tzdata.
# Usage: FROM ghcr.io/codehunters-io/ci-base-images:X.Y.Z-node-runtime

FROM node:20.20.2-alpine

# No build-base and no python3. A dependency that needs node-gyp compiles in the
# builder stage; shipping a C toolchain in the image that faces traffic hands an
# attacker a compiler.
RUN set -eux; \
    apk add --no-cache tini tzdata ca-certificates; \
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
