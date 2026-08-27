#!/usr/bin/env bash
# Install Gradle CLI matching ./gradlew wrapper version across codehunters-ms-* repos.
# Verifies SHA-256 against official gradle.org checksum endpoint.
set -euo pipefail

GRADLE_VERSION="${GRADLE_VERSION:-9.0.0}"
GRADLE_BASE_URL="https://services.gradle.org/distributions"
GRADLE_ZIP="gradle-${GRADLE_VERSION}-bin.zip"
INSTALL_DIR="/opt/gradle"

cd /tmp

echo "Downloading ${GRADLE_ZIP}..."
curl -fSL -o "${GRADLE_ZIP}" "${GRADLE_BASE_URL}/${GRADLE_ZIP}"
curl -fSL -o "${GRADLE_ZIP}.sha256" "${GRADLE_BASE_URL}/${GRADLE_ZIP}.sha256"

EXPECTED_SHA="$(cat "${GRADLE_ZIP}.sha256")"
ACTUAL_SHA="$(sha256sum "${GRADLE_ZIP}" | awk '{print $1}')"

if [ "${EXPECTED_SHA}" != "${ACTUAL_SHA}" ]; then
    echo "Gradle checksum mismatch!" >&2
    echo "Expected: ${EXPECTED_SHA}" >&2
    echo "Actual:   ${ACTUAL_SHA}" >&2
    exit 1
fi
echo "Gradle SHA-256 OK."

mkdir -p "${INSTALL_DIR}"
unzip -q "${GRADLE_ZIP}" -d "${INSTALL_DIR}"
rm -f "${GRADLE_ZIP}" "${GRADLE_ZIP}.sha256"

GRADLE_HOME="${INSTALL_DIR}/gradle-${GRADLE_VERSION}"

# Strip non-runtime assets to shrink image. `:?` on every path: an unset
# GRADLE_HOME would expand these to /docs, /src, /media at the image root.
rm -rf \
    "${GRADLE_HOME:?}/docs" \
    "${GRADLE_HOME:?}/samples" \
    "${GRADLE_HOME:?}/src" \
    "${GRADLE_HOME:?}/media" \
    "${GRADLE_HOME:?}/init.d"

ln -sf "${GRADLE_HOME}/bin/gradle" /usr/local/bin/gradle

gradle --version | grep -q "Gradle ${GRADLE_VERSION}"
echo "Gradle ${GRADLE_VERSION} installed."
