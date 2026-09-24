# syntax=docker/dockerfile:1.7
# ci-base-images (GraalVM 25 variant) — pre-baked CI image for codehunters-ms-*
# native-image pipelines that have moved to the JDK 25 LTS.
# Contents: GraalVM CE for JDK 25 (Oracle Linux 9 / glibc) with native-image,
# Gradle, AWS CLI v2, Docker CLI + buildx.
# Usage: jobs.<id>.container: ghcr.io/codehunters-io/ci-base-images:vX.Y.Z-graalvm25
#
# A second directory rather than an ARG over the FROM in images/ci/graalvm: see
# the note in images/ci/jdk25/Dockerfile for why the FROM stays literal.

FROM ghcr.io/graalvm/native-image-community:25@sha256:0d936f32bb8acb5bc60c41b33e05f064d7a6aaf36b726538296c54949bd4a3c0

# No default: BuildKit fills TARGETARCH with the platform being built, but only
# for an ARG declared without one. `ARG TARGETARCH=amd64` shadows it, and the
# arm64 build then downloads x86_64 artefacts.
ARG TARGETARCH
ARG GRADLE_VERSION=9.7.1
# Pinned, not `latest`: this variant installs the official bundle, and an
# unpinned URL makes every rebuild fetch a different artifact. Bump deliberately.
ARG AWS_CLI_VERSION=2.36.32
ARG AWS_CLI_VERIFY_GPG=1

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    GRADLE_HOME=/opt/gradle/gradle-${GRADLE_VERSION} \
    GRADLE_USER_HOME=/root/.gradle \
    CI_VARIANT=graalvm \
    CI_JAVA_MAJOR=25 \
    PATH=${JAVA_HOME}/bin:/opt/gradle/gradle-${GRADLE_VERSION}/bin:/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin

COPY scripts/ /usr/local/bin/

# One RUN per component rather than one for all four. The layers are the unit
# of transfer, so a Gradle bump used to reship the base packages, the AWS CLI
# and the Docker CLI with it. Each ends in cleanup.sh because a later layer
# cannot shrink an earlier one: deleting a file that a previous layer created
# writes a whiteout and adds bytes rather than removing them. That is also why
# cleanup-ol.sh drops the message catalogues per layer instead of once at
# the end.
#
# No PYTHONDONTWRITEBYTECODE here, unlike the Alpine variants: this image
# installs the AWS CLI from the official bundle, which is a PyInstaller build
# carrying its own precompiled interpreter and writes no __pycache__. Verified
# on the published image - zero cache directories.
RUN set -eux; \
    chmod +x /usr/local/bin/*.sh; \
    /usr/local/bin/install-base-packages.sh; \
    /usr/local/bin/cleanup.sh

RUN set -eux; \
    TARGETARCH="${TARGETARCH}" AWS_CLI_VERSION="${AWS_CLI_VERSION}" AWS_CLI_VERIFY_GPG="${AWS_CLI_VERIFY_GPG}" \
        /usr/local/bin/install-aws-cli.sh; \
    /usr/local/bin/cleanup.sh

RUN set -eux; \
    /usr/local/bin/install-docker-cli.sh; \
    /usr/local/bin/cleanup.sh

RUN set -eux; \
    GRADLE_VERSION="${GRADLE_VERSION}" /usr/local/bin/install-gradle.sh; \
    /usr/local/bin/cleanup.sh

RUN set -eux; \
    /usr/local/bin/install-native-image.sh; \
    /usr/local/bin/smoke-test.sh

LABEL org.opencontainers.image.title="ci-base-images" \
      org.opencontainers.image.description="CI base image for codehunters-ms-* native-image pipelines (GraalVM CE for JDK 25, Gradle, AWS CLI v2, Docker CLI)" \
      org.opencontainers.image.source="https://github.com/Codehunters-IO/ci-base-images" \
      org.opencontainers.image.vendor="codehunters" \
      org.opencontainers.image.licenses="MIT" \
      io.codehunters.usage="ci-only" \
      io.codehunters.variant="graalvm25" \
      io.codehunters.contents.java="graalvm-ce-25" \
      io.codehunters.contents.libc="glibc" \
      io.codehunters.contents.base="ghcr.io/graalvm/native-image-community:25" \
      io.codehunters.contents.native-image="25" \
      io.codehunters.contents.gradle="${GRADLE_VERSION}"

WORKDIR /workspace
ENTRYPOINT []
CMD ["/bin/bash"]
