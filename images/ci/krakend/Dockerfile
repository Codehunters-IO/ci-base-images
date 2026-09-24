# syntax=docker/dockerfile:1.7
# ci-base-images (KrakenD variant) — pre-baked CI image for
# codehunters-gw-krakend gateway pipelines.
# Contents: KrakenD CLI, Go toolchain (matched to krakend/builder), build-base
# + binutils-gold for `-buildmode=plugin`, make, AWS CLI v2,
# Docker CLI + buildx, GNU userland.
# Usage: jobs.<id>.container: ghcr.io/codehunters/ci-base-images:vX.Y.Z-krakend

ARG KRAKEND_VERSION=2.13.11
ARG GO_VERSION=1.26.8

# Stage 1 — pull the KrakenD CLI binary from the official image.
FROM krakend:2.13.11@sha256:26eb32dbb0e679c62170b21b4efb0729dc00262afd98fe6210110dbbbdd6425f AS krakend-src

# Stage 2 — pull the Go toolchain from the official Alpine image (apk Go is
# typically behind the version used by krakend/builder; matching the exact
# build-image Go version is required for `-buildmode=plugin` ABI compat).
#
# GO_VERSION is not a free choice: it must equal the toolchain the pinned
# KrakenD release was built with, or plugins refuse to load at runtime. Read it
# off the binary rather than guessing:
#
#   id=$(docker create krakend:2.13.11)
#   docker cp "$id:/usr/bin/krakend" /tmp/krakend && docker rm -f "$id"
#   go version -m /tmp/krakend | head -1    # -> go1.26.8
#
# Bump KRAKEND_VERSION and GO_VERSION together, never apart.
FROM golang:1.26.8-alpine@sha256:ce864e7223ac17b1775e6fd0b4c0db580c2eb50e7953a427916379e4b92a1628 AS go-src

# Pruned here rather than after the COPY below: a deletion in a later layer
# writes a whiteout and the bytes still ship. `test/` and `api/` are the Go
# distribution's own conformance suite and API-compatibility manifests — 30 MB
# that no consumer build reads. `src/` stays: since Go 1.20 there is no
# precompiled standard library, and the compiler builds it from these sources.
RUN rm -rf /usr/local/go/test /usr/local/go/api /usr/local/go/doc

# Stage 3 — final CI image.
FROM alpine:3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

# No default: BuildKit fills TARGETARCH with the platform being built, but only
# for an ARG declared without one. `ARG TARGETARCH=amd64` shadows it, and the
# arm64 build then downloads x86_64 artefacts.
ARG TARGETARCH
ARG KRAKEND_VERSION=2.13.11
ARG GO_VERSION=1.26.8
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
COPY --from=krakend-src /usr/bin/krakend /usr/local/bin/krakend
COPY --from=go-src      /usr/local/go    /usr/local/go

# Build-time only, cleared below. The AWS CLI is a Python program, so every
# `aws` invocation during the build writes bytecode caches next to the modules
# it imports — 99 MB of __pycache__ in the published image, measured.
# cleanup.sh deleted it and the smoke test recreated it.
ENV PYTHONDONTWRITEBYTECODE=1

# One RUN per component rather than one for all of them: the layers are the
# unit of transfer. Each ends in cleanup.sh because a later layer cannot shrink
# an earlier one — deleting a file a previous layer created writes a whiteout
# and adds bytes rather than removing them.
RUN set -eux; \
    chmod +x /usr/local/bin/*.sh; \
    /usr/local/bin/install-base-packages.sh; \
    apk add --no-cache \
        build-base \
        binutils-gold \
        make; \
    /usr/local/bin/cleanup.sh

RUN set -eux; \
    TARGETARCH="${TARGETARCH}" AWS_CLI_VERSION="${AWS_CLI_VERSION}" AWS_CLI_VERIFY_GPG="${AWS_CLI_VERIFY_GPG}" \
        /usr/local/bin/install-aws-cli.sh; \
    /usr/local/bin/cleanup.sh

RUN set -eux; \
    /usr/local/bin/install-docker-cli.sh; \
    /usr/local/bin/install-krakend.sh; \
    /usr/local/bin/install-go.sh; \
    /usr/local/bin/cleanup.sh

RUN /usr/local/bin/smoke-test.sh

# Empty, not absent: Python only honours the variable when it is non-empty, so
# this restores default behaviour for whatever the consumer runs.
ENV PYTHONDONTWRITEBYTECODE=

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
