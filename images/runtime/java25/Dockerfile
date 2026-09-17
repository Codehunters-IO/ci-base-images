# syntax=docker/dockerfile:1.7
# ci-base-images (Java 25 runtime) — base for codehunters-ms-* application images
# that have moved to the JDK 25 LTS.
# Contents: Temurin JRE 25 (Alpine/musl), tini, CA certificates, tzdata.
# Usage: FROM ghcr.io/codehunters-io/ci-base-images:X.Y.Z-java25-runtime
#
# A second directory rather than an ARG over the FROM in images/runtime/java: see
# the note in images/ci/jdk25/Dockerfile for why the FROM stays literal.

FROM eclipse-temurin:25-jre-alpine@sha256:3137541deb3cac6626b5d9a4a2187bc0d6a34312f858bd2c67dd01e732e6b682

ARG APP_UID=10001
ARG APP_GID=10001

# JRE, not JDK: an application image has no reason to carry javac, jlink or the
# rest of the toolchain. That is the builder stage's job, and every tool left
# behind here is surface an attacker inherits along with the app.
# apk upgrade before apk add: the upstream tag is rebuilt on its own cadence,
# and between rebuilds it accumulates patched-upstream CVEs. Five fixable
# CRITICAL/HIGH (openssl, expat) on the day this was written; zero after.
# It costs reproducibility — two builds of the same Dockerfile can differ — and
# that is the trade a base image is supposed to make: it is rebuilt and
# republished on a schedule precisely so consumers inherit the patches.
RUN set -eux; \
    apk upgrade --no-cache; \
    apk add --no-cache tini tzdata ca-certificates; \
    addgroup -g "${APP_GID}" -S app; \
    adduser -u "${APP_UID}" -G app -S -H -s /sbin/nologin app; \
    mkdir -p /app; \
    chown app:app /app

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    CI_JAVA_MAJOR=25 \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"

WORKDIR /app
USER app

# tini as PID 1. The JVM handles SIGTERM for its shutdown hooks, but it does not
# reap orphaned children, and anything the app forks would accumulate as zombies.
ENTRYPOINT ["/sbin/tini", "--"]

LABEL org.opencontainers.image.title="ci-base-images (java 25 runtime)" \
      org.opencontainers.image.description="Runtime base for codehunters-ms-* Java services (Temurin JRE 25, non-root, tini)" \
      org.opencontainers.image.source="https://github.com/Codehunters-IO/ci-base-images" \
      org.opencontainers.image.vendor="codehunters" \
      org.opencontainers.image.licenses="MIT" \
      io.codehunters.usage="runtime" \
      io.codehunters.variant="java25-runtime" \
      io.codehunters.contents.java="25-jre" \
      io.codehunters.contents.libc="musl" \
      io.codehunters.contents.base="eclipse-temurin:25-jre-alpine" \
      io.codehunters.runs-as="app"
