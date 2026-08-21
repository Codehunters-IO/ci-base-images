#!/usr/bin/env bash
# Verifier — confirms the Node toolchain is usable for CI and enables corepack.
#
# Node, npm and npx come from the `node:${NODE_VERSION}-alpine` base image; this
# script does not install them, it proves they are there and reports versions.
#
# corepack ships with Node 20 but is inert until enabled. Enabling it here means
# a consumer can run `pnpm install` or `yarn install` without a setup action —
# the package manager is resolved from the repository's `packageManager` field
# at first use. The download happens at run time, not build time, so the image
# stays agnostic about which package manager a repository picked.
#
# Also verifies the node-gyp fallback path (python3 + cc + make): a dependency
# published without a linux-musl prebuild compiles from source at `npm ci`.
set -euo pipefail

for bin in node npm npx corepack; do
    command -v "${bin}" >/dev/null 2>&1 || { echo "Missing Node toolchain binary: ${bin}" >&2; exit 1; }
done

for bin in python3 cc make; do
    command -v "${bin}" >/dev/null 2>&1 || { echo "Missing node-gyp build dep: ${bin}" >&2; exit 1; }
done

corepack enable

node --version
npm --version
python3 --version
echo "Node toolchain + node-gyp build deps OK."
