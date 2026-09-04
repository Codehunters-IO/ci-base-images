# syntax=docker/dockerfile:1.7
# ci-base-images (JDK variant) — pre-baked CI image for codehunters-ms-* Java pipelines.
# Contents: Temurin JDK 21 (Alpine/musl), Gradle, AWS CLI v2, Docker CLI + buildx.
# Usage: jobs.<id>.container: ghcr.io/codehunters/ci-base-images:vX.Y.Z

FROM eclipse-temurin:21-jdk-alpine

# No default: BuildKit fills TARGETARCH with the platform being built, but only
# for an ARG declared without one. `ARG TARGETARCH=amd64` shadows it, and the
# arm64 build then downloads x86_64 artefacts.
ARG TARGETARCH
ARG GRADLE_VERSION=9.7.1
# AWS_CLI_VERSION only applies if AWS_CLI_FROM_BUNDLE=1 forces the glibc bundle;
# the musl path installs aws-cli from the Alpine community repo and ignores it.
# The pin is the last release that ran under gcompat, kept for that escape hatch.
ARG AWS_CLI_VERSION=2.17.65
ARG AWS_CLI_VERIFY_GPG=1

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JAVA_HOME=/opt/java/openjdk \
    GRADLE_HOME=/opt/gradle/gradle-${GRADLE_VERSION} \
    GRADLE_USER_HOME=/root/.gradle \
    CI_VARIANT=jdk \
    PATH=/opt/java/openjdk/bin:/opt/gradle/gradle-${GRADLE_VERSION}/bin:/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin

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
      org.opencontainers.image.description="CI base image for codehunters-ms-* Java pipelines (JDK 21, Gradle, AWS CLI v2, Docker CLI)" \
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
