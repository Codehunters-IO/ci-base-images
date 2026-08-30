# syntax=docker/dockerfile:1.7
# ci-base-images (Java runtime) — base for codehunters-ms-* application images.
# Contents: Temurin JRE 21 (Alpine/musl), tini, CA certificates, tzdata.
# Usage: FROM ghcr.io/codehunters-io/ci-base-images:X.Y.Z-java-runtime

FROM eclipse-temurin:25-jre-alpine

ARG APP_UID=10001
ARG APP_GID=10001

# JRE, not JDK: an application image has no reason to carry javac, jlink or the
# rest of the toolchain. That is the builder stage's job, and every tool left
# behind here is surface an attacker inherits along with the app.
RUN set -eux; \
    apk add --no-cache tini tzdata ca-certificates; \
    addgroup -g "${APP_GID}" -S app; \
    adduser -u "${APP_UID}" -G app -S -H -s /sbin/nologin app; \
    mkdir -p /app; \
    chown app:app /app

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"

WORKDIR /app
USER app

# tini as PID 1. The JVM handles SIGTERM for its shutdown hooks, but it does not
# reap orphaned children, and anything the app forks would accumulate as zombies.
ENTRYPOINT ["/sbin/tini", "--"]

LABEL org.opencontainers.image.title="ci-base-images (java runtime)" \
      org.opencontainers.image.description="Runtime base for codehunters-ms-* Java services (Temurin JRE 21, non-root, tini)" \
      org.opencontainers.image.source="https://github.com/Codehunters-IO/ci-base-images" \
      org.opencontainers.image.vendor="codehunters" \
      org.opencontainers.image.licenses="MIT" \
      io.codehunters.usage="runtime" \
      io.codehunters.variant="java-runtime" \
      io.codehunters.contents.java="21-jre" \
      io.codehunters.contents.libc="musl" \
      io.codehunters.contents.base="eclipse-temurin:21-jre-alpine" \
      io.codehunters.runs-as="app"
