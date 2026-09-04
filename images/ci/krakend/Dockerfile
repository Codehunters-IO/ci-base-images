# syntax=docker/dockerfile:1.7
# ci-base-images (KrakenD variant) — pre-baked CI image for
# codehunters-gw-krakend gateway pipelines.
# Contents: KrakenD CLI, Go toolchain (matched to krakend/builder), build-base
# + binutils-gold for `-buildmode=plugin`, make, AWS CLI v2,
# Docker CLI + buildx, GNU userland.
# Usage: jobs.<id>.container: ghcr.io/codehunters/ci-base-images:vX.Y.Z-krakend

ARG KRAKEND_VERSION=2.13.4
ARG GO_VERSION=1.25.7

# Stage 1 — pull the KrakenD CLI binary from the official image.
FROM krakend:2.13.4@sha256:93031947cd8e0b438cbb28d53476f46d4e609f69afac294ce2e1517b02b76774 AS krakend-src

# Stage 2 — pull the Go toolchain from the official Alpine image (apk Go is
# typically behind the version used by krakend/builder; matching the exact
# build-image Go version is required for `-buildmode=plugin` ABI compat).
FROM golang:1.25.7-alpine@sha256:f6751d823c26342f9506c03797d2527668d095b0a15f1862cddb4d927a7a4ced AS go-src

# Stage 3 — final CI image.
FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

# No default: BuildKit fills TARGETARCH with the platform being built, but only
# for an ARG declared without one. `ARG TARGETARCH=amd64` shadows it, and the
# arm64 build then downloads x86_64 artefacts.
ARG TARGETARCH
ARG KRAKEND_VERSION=2.13.4
ARG GO_VERSION=1.25.7
# AWS_CLI_VERSION only applies if AWS_CLI_FROM_BUNDLE=1 forces the glibc bundle;
# the musl path installs aws-cli from the Alpine community repo and ignores it.
# The pin is the last release that ran under gcompat, kept for that escape hatch.
ARG AWS_CLI_VERSION=2.17.65
ARG AWS_CLI_VERIFY_GPG=1

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
      org.opencontainers.image.description="CI base image for codehunters-gw-krakend pipelines (KrakenD CLI, Go toolchain, plugin build deps, AWS CLI v2, Docker CLI)" \
      org.opencontainers.image.source="https://github.com/codehunters/ci-base-images" \
      org.opencontainers.image.vendor="codehunters" \
      org.opencontainers.image.licenses="MIT" \
      io.codehunters.usage="ci-only" \
      io.codehunters.variant="krakend" \
      io.codehunters.contents.krakend="${KRAKEND_VERSION}" \
      io.codehunters.contents.go="${GO_VERSION}" \
      io.codehunters.contents.libc="musl" \
      io.codehunters.contents.base="alpine:3.24"

WORKDIR /workspace
ENTRYPOINT []
CMD ["/bin/bash"]
