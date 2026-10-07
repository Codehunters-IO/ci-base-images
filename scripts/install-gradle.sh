#!/usr/bin/env bash
# Install Gradle CLI matching ./gradlew wrapper version across codehunters-ms-* repos.
# Verifies SHA-256 against official gradle.org checksum endpoint.
set -euo pipefail

GRADLE_VERSION="${GRADLE_VERSION:-9.7.1}"
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

# Libraries the Gradle distribution bundles at a version with a published fix
# that Gradle has not shipped yet: 9.7.1 and 9.8.0 both carry jackson 2.22.0
# and jsoup 1.22.2, five fixable HIGH and one between them. Each is swapped for
# the fixed release, pinned by SHA-256 like the distribution itself.
#
# Gradle does not scan lib/ for jars: every library has a <name>.properties
# next to it naming `jarFile` and `alias.version`, and the module registry
# loads exactly that file. So the jar goes in under its real name and the
# descriptor is rewritten to match, rather than new bytes hiding behind the old
# filename. Patch releases only for jackson: its modules must share a minor,
# and the datatype modules Gradle also bundles stay on 2.22.0.
#
# Entries: <descriptor>:<maven path>:<artifact>:<version>:<sha256>. Drop one
# when GRADLE_VERSION moves to a release that bundles the fix.
GRADLE_PATCHES="${GRADLE_PATCHES:-\
jackson-core:com/fasterxml/jackson/core:jackson-core:2.22.3:8a501126a385b25841915d839508f8a66e2a0dbc8a6709d055ef3b3e852b094c \
jackson-databind:com/fasterxml/jackson/core:jackson-databind:2.22.3:556db5439e206114346043f68d200497dc96a0bca62a360a81784092ebd0e0a9 \
jsoup:org/jsoup:jsoup:1.23.2:e9d8c856856680427f096d156f02a414289985c930998fcb519ce5be39b42003}"

patch_gradle_lib() {
    local descriptor="$1" path="$2" artifact="$3" version="$4" sha="$5"
    local lib="${GRADLE_HOME}/lib" props="${GRADLE_HOME}/lib/${descriptor}.properties"
    local old_jar new_jar="${artifact}-${version}.jar"

    [ -f "${props}" ] || { echo "No ${props}: Gradle ${GRADLE_VERSION} does not bundle ${descriptor}" >&2; exit 1; }
    old_jar="$(sed -n 's/^jarFile=//p' "${props}")"

    curl -fSL -o "/tmp/${new_jar}" "https://repo1.maven.org/maven2/${path}/${artifact}/${version}/${new_jar}"
    echo "${sha}  /tmp/${new_jar}" | sha256sum -c - >/dev/null \
        || { echo "Checksum mismatch for ${new_jar}" >&2; exit 1; }

    rm -f "${lib:?}/${old_jar}"
    mv "/tmp/${new_jar}" "${lib}/${new_jar}"
    sed -i -e "s/^alias\.version=.*/alias.version=${version}/" \
           -e "s/^jarFile=.*/jarFile=${new_jar}/" "${props}"
    echo "Patched ${old_jar} -> ${new_jar}"
}

for entry in ${GRADLE_PATCHES}; do
    IFS=: read -r descriptor path artifact version sha <<< "${entry}"
    patch_gradle_lib "${descriptor}" "${path}" "${artifact}" "${version}" "${sha}"
done

ln -sf "${GRADLE_HOME}/bin/gradle" /usr/local/bin/gradle

gradle --version | grep -q "Gradle ${GRADLE_VERSION}"
echo "Gradle ${GRADLE_VERSION} installed."
