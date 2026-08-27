# syntax=docker/dockerfile:1.7
# ci-base-images (GraalVM variant) — pre-baked CI image for
# codehunters-ms-* native-image pipelines.
# Contents: GraalVM CE for JDK 21 (Oracle Linux 9 / glibc) with native-image,
# Gradle, WireGuard tools (via EPEL), AWS CLI v2, Docker CLI + buildx.
# Usage: jobs.<id>.container: ghcr.io/codehunters/ci-base-images:vX.Y.Z-graalvm

FROM ghcr.io/graalvm/jdk-community:21

ARG TARGETARCH=amd64
ARG GRADLE_VERSION=9.0.0
ARG AWS_CLI_VERSION=latest
ARG AWS_CLI_VERIFY_GPG=0

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    GRADLE_HOME=/opt/gradle/gradle-${GRADLE_VERSION} \
    GRADLE_USER_HOME=/root/.gradle \
    CI_VARIANT=graalvm \
    PATH=/opt/gradle/gradle-${GRADLE_VERSION}/bin:/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin

COPY scripts/ /usr/local/bin/

RUN set -eux; \
    chmod +x /usr/local/bin/*.sh; \
    /usr/local/bin/install-base-packages.sh; \
    TARGETARCH="${TARGETARCH}" AWS_CLI_VERSION="${AWS_CLI_VERSION}" AWS_CLI_VERIFY_GPG="${AWS_CLI_VERIFY_GPG}" \
        /usr/local/bin/install-aws-cli.sh; \
    /usr/local/bin/install-docker-cli.sh; \
    GRADLE_VERSION="${GRADLE_VERSION}" /usr/local/bin/install-gradle.sh; \
    /usr/local/bin/install-native-image.sh; \
    /usr/local/bin/cleanup.sh; \
    /usr/local/bin/smoke-test.sh

LABEL org.opencontainers.image.title="ci-base-images" \
      org.opencontainers.image.description="CI base image for codehunters-ms-* native-image pipelines (GraalVM CE for JDK 21, Gradle, WireGuard, AWS CLI v2, Docker CLI)" \
      org.opencontainers.image.source="https://github.com/codehunters/ci-base-images" \
      org.opencontainers.image.vendor="codehunters" \
      org.opencontainers.image.licenses="MIT" \
      io.codehunters.usage="ci-only" \
      io.codehunters.variant="graalvm" \
      io.codehunters.contents.java="graalvm-ce-21" \
      io.codehunters.contents.libc="glibc" \
      io.codehunters.contents.base="ghcr.io/graalvm/jdk-community:21" \
      io.codehunters.contents.native-image="21" \
      io.codehunters.contents.gradle="${GRADLE_VERSION}"

WORKDIR /workspace
ENTRYPOINT []
CMD ["/bin/bash"]
