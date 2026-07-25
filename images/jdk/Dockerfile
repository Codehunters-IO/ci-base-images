# syntax=docker/dockerfile:1.7
# ci-base-images (JDK variant) — pre-baked CI image for codehunters-ms-* Java pipelines.
# Contents: Temurin JDK 21 (Alpine/musl), Gradle, WireGuard tools, AWS CLI v2, Docker CLI + buildx.
# Usage: jobs.<id>.container: ghcr.io/codehunters/ci-base-images:vX.Y.Z

FROM eclipse-temurin:21-jdk-alpine

ARG TARGETARCH=amd64
ARG GRADLE_VERSION=9.0
# AWS CLI pin on musl: last gcompat-compatible release (Python 3.11). v2.18+
# bundles Python 3.14 which needs the `dladdr1` glibc symbol absent in gcompat.
ARG AWS_CLI_VERSION=2.17.65
ARG AWS_CLI_VERIFY_GPG=0

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JAVA_HOME=/opt/java/openjdk \
    GRADLE_HOME=/opt/gradle/gradle-${GRADLE_VERSION} \
    GRADLE_USER_HOME=/root/.gradle \
    CI_VARIANT=jdk \
    PATH=/opt/gradle/gradle-${GRADLE_VERSION}/bin:/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin

COPY scripts/ /usr/local/bin/

RUN set -eux; \
    chmod +x /usr/local/bin/*.sh; \
    /usr/local/bin/install-base-packages.sh; \
    TARGETARCH="${TARGETARCH}" AWS_CLI_VERSION="${AWS_CLI_VERSION}" AWS_CLI_VERIFY_GPG="${AWS_CLI_VERIFY_GPG}" \
        /usr/local/bin/install-aws-cli.sh; \
    /usr/local/bin/install-docker-cli.sh; \
    GRADLE_VERSION="${GRADLE_VERSION}" /usr/local/bin/install-gradle.sh; \
    /usr/local/bin/cleanup.sh; \
    /usr/local/bin/smoke-test.sh

LABEL org.opencontainers.image.title="ci-base-images" \
      org.opencontainers.image.description="CI base image for codehunters-ms-* Java pipelines (JDK 21, Gradle, WireGuard, AWS CLI v2, Docker CLI)" \
      org.opencontainers.image.source="https://github.com/codehunters/ci-base-images" \
      org.opencontainers.image.vendor="codehunters" \
      org.opencontainers.image.licenses="MIT" \
      io.codehunters.usage="ci-only" \
      io.codehunters.variant="jdk" \
      io.codehunters.contents.java="21" \
      io.codehunters.contents.libc="musl" \
      io.codehunters.contents.base="eclipse-temurin:21-jdk-alpine" \
      io.codehunters.contents.gradle="${GRADLE_VERSION}"

WORKDIR /workspace
ENTRYPOINT []
CMD ["/bin/bash"]
