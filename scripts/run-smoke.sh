#!/usr/bin/env bash
# Host-side dispatcher: each image family is tested differently, and the
# difference is not incidental.
#
#   ci       the test script is baked into the image, which is fine for a CI
#            image and would be dead weight in a runtime one
#   runtime  the script is mounted, because runtime images carry no test code
#   web      same, but the entrypoint is nginx and has to be overridden
#   native   nothing runs inside: no shell. Asserted from the host instead.
#
# Env: IMAGE (required), KIND, VARIANT, PLATFORM (optional)
set -euo pipefail

IMAGE="${IMAGE:?set IMAGE}"
KIND="${KIND:-ci}"
VARIANT="${VARIANT:-}"
PLAT=""
[ -n "${PLATFORM:-}" ] && PLAT="--platform ${PLATFORM}"
SCRIPT="$(cd "$(dirname "$0")" && pwd)/smoke-test-runtime.sh"

case "${KIND}" in
    ci)
        # shellcheck disable=SC2086
        docker run --rm ${PLAT} -e CI_VARIANT="${VARIANT}" \
            "${IMAGE}" /usr/local/bin/smoke-test.sh
        ;;
    runtime)
        # shellcheck disable=SC2086
        docker run --rm ${PLAT} -e RUNTIME_VARIANT="${VARIANT}" \
            -v "${SCRIPT}:/tmp/smoke.sh:ro" "${IMAGE}" sh /tmp/smoke.sh
        ;;
    web)
        # shellcheck disable=SC2086
        docker run --rm ${PLAT} --entrypoint sh -e RUNTIME_VARIANT=web \
            -v "${SCRIPT}:/tmp/smoke.sh:ro" "${IMAGE}" /tmp/smoke.sh
        ;;
    native)
        IMAGE="${IMAGE}" "$(dirname "$0")/smoke-test-native.sh"
        ;;
    *)
        echo "unknown KIND=${KIND}" >&2
        exit 1
        ;;
esac
