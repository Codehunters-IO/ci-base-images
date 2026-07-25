# syntax=docker/dockerfile:1.7
# ci-base-images (KrakenD variant) — pre-baked CI image for
# codehunters-gw-krakend gateway pipelines.
# Contents: KrakenD CLI, Go toolchain (matched to krakend/builder), build-base
# + binutils-gold for `-buildmode=plugin`, make, WireGuard tools, AWS CLI v2,
# Docker CLI + buildx, GNU userland.
# Usage: jobs.<id>.container: ghcr.io/codehunters/ci-base-images:vX.Y.Z-krakend

ARG KRAKEND_VERSION=2.13.4
ARG GO_VERSION=1.25.7

# Stage 1 — pull the KrakenD CLI binary from the official image.
FROM krakend:${KRAKEND_VERSION} AS krakend-src

# Stage 2 — pull the Go toolchain from the official Alpine image (apk Go is
# typically behind the version used by krakend/builder; matching the exact
# build-image Go version is required for `-buildmode=plugin` ABI compat).
FROM golang:${GO_VERSION}-alpine AS go-src

# Stage 3 — final CI image.
FROM alpine:3.21

ARG TARGETARCH=amd64
ARG KRAKEND_VERSION=2.13.4
ARG GO_VERSION=1.25.7
# AWS CLI pin on musl: last gcompat-compatible release (Python 3.11).
ARG AWS_CLI_VERSION=2.17.65
ARG AWS_CLI_VERIFY_GPG=0

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    GOROOT=/usr/local/go \
    GOPATH=/root/go \
    CGO_ENABLED=1 \
    CI_VARIANT=krakend \
    PATH=/usr/local/go/bin:/root/go/bin:/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin

COPY scripts/ /usr/local/bin/

# Copy KrakenD CLI and Go toolchain from the source images.
COPY --from=krakend-src /usr/bin/krakend /usr/local/bin/krakend
COPY --from=go-src      /usr/local/go    /usr/local/go

RUN set -eux; \
    chmod +x /usr/local/bin/*.sh; \
    /usr/local/bin/install-base-packages.sh; \
    # KrakenD-variant extras: Go plugin build deps + make for Makefile-driven CI.
    apk add --no-cache \
        build-base \
        binutils-gold \
        make; \
    TARGETARCH="${TARGETARCH}" AWS_CLI_VERSION="${AWS_CLI_VERSION}" AWS_CLI_VERIFY_GPG="${AWS_CLI_VERIFY_GPG}" \
        /usr/local/bin/install-aws-cli.sh; \
    /usr/local/bin/install-docker-cli.sh; \
    /usr/local/bin/install-krakend.sh; \
    /usr/local/bin/install-go.sh; \
    /usr/local/bin/cleanup.sh; \
    /usr/local/bin/smoke-test.sh

LABEL org.opencontainers.image.title="ci-base-images" \
      org.opencontainers.image.description="CI base image for codehunters-gw-krakend pipelines (KrakenD CLI, Go toolchain, plugin build deps, WireGuard, AWS CLI v2, Docker CLI)" \
      org.opencontainers.image.source="https://github.com/codehunters/ci-base-images" \
      org.opencontainers.image.vendor="codehunters" \
      org.opencontainers.image.licenses="MIT" \
      io.codehunters.usage="ci-only" \
      io.codehunters.variant="krakend" \
      io.codehunters.contents.krakend="${KRAKEND_VERSION}" \
      io.codehunters.contents.go="${GO_VERSION}" \
      io.codehunters.contents.libc="musl" \
      io.codehunters.contents.base="alpine:3.21"

WORKDIR /workspace
ENTRYPOINT []
CMD ["/bin/bash"]
