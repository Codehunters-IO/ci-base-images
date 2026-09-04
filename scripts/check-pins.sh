#!/usr/bin/env bash
# Asserts that what a Dockerfile pins and what it claims to pin are the same
# thing.
#
# Three failures this catches, all of which have already happened here or come
# close to it:
#
#   1. A FROM without a digest. The tag alone is a promise the registry is free
#      to break, and a rebuild then silently ships a different base.
#   2. A contents.base label that disagrees with the final FROM. images/ci/krakend
#      claimed alpine:3.21 while building on 3.24 for weeks — the provenance
#      metadata consumers read was simply wrong.
#   3. A version ARG that disagrees with the tag in its own FROM. The FROMs are
#      literal so Dependabot can update the digests, which means the version now
#      appears twice in those files; this is what stops the copies drifting.
set -euo pipefail

cd "$(dirname "$0")/.."
fail=0
note() { printf "  [FAIL] %s\n" "$1" >&2; fail=1; }

dockerfiles=$(find images -name Dockerfile | sort)

for df in ${dockerfiles}; do
    # 1 — every FROM carries a digest
    while IFS= read -r line; do
        case "${line}" in
            *"@sha256:"*) ;;
            *) note "${df}: FROM without a digest: ${line}" ;;
        esac
    done < <(grep '^FROM ' "${df}")

    # 2 — contents.base label matches the final stage's FROM
    final=$(grep '^FROM ' "${df}" | tail -1 \
            | sed -e 's/^FROM //' -e 's/ AS .*//' -e 's/@sha256:[0-9a-f]*//')
    label=$(sed -n 's/.*io\.codehunters\.contents\.base="\([^"]*\)".*/\1/p' "${df}")
    # A label may reference a build ARG, as ci/node does with ${NODE_VERSION}.
    # Docker expands it at build time; expand it here too rather than forcing
    # the value to be written out twice.
    while IFS='=' read -r name value; do
        [ -n "${name}" ] || continue
        label=${label//\$\{${name}\}/${value}}
    done < <(sed -n 's/^ARG \([A-Z_]*\)=\(.*\)$/\1=\2/p' "${df}")
    if [ -z "${label}" ]; then
        note "${df}: no io.codehunters.contents.base label"
    elif [ "${label}" != "${final}" ]; then
        note "${df}: label says '${label}', final FROM is '${final}'"
    fi
done

# 3 — version ARGs that are duplicated into a literal FROM must agree with it.
#     Columns: dockerfile, ARG name, image name as it appears in the FROM.
check_arg_matches_from() {
    df="$1"; arg="$2"; image="$3"
    value=$(sed -n "s/^ARG ${arg}=\(.*\)$/\1/p" "${df}" | sort -u)
    if [ -z "${value}" ]; then
        note "${df}: expected ARG ${arg}, not found"; return
    fi
    if [ "$(printf '%s\n' "${value}" | wc -l)" -ne 1 ]; then
        note "${df}: ARG ${arg} declared with conflicting values: ${value}"; return
    fi
    if ! grep -qE "^FROM ([^ ]*/)?${image}:${value}(-[a-z0-9.]+)?@sha256:" "${df}"; then
        note "${df}: ARG ${arg}=${value} has no matching '${image}:${value}' FROM"
    fi
}

check_arg_matches_from images/ci/krakend/Dockerfile KRAKEND_VERSION krakend
check_arg_matches_from images/ci/krakend/Dockerfile GO_VERSION     golang
check_arg_matches_from images/ci/node/Dockerfile    NODE_VERSION   node

if [ "${fail}" -ne 0 ]; then
    echo "" >&2
    echo "Pin consistency check FAILED." >&2
    exit 1
fi

echo "Pin consistency OK — $(echo "${dockerfiles}" | wc -l | tr -d ' ') Dockerfiles."
