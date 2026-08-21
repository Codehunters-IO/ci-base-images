# Changelog

All notable changes to this project will be documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Node variant** published under `-node` tag suffix (`:vX.Y.Z-node`, `:node`
  rolling tag on `main`). Base image `node:20.20.2-alpine` (musl), ~210 MB.
  Ships npm and corepack (pnpm/yarn resolved from the consumer's
  `packageManager` field at first use), plus `build-base` + `python3` for the
  node-gyp fallback path. Node 20 rather than 22 because the consumers pin it
  (`.nvmrc`, `engines: ">=20 <21"`). For Hardhat/Solidity and TypeScript SDK
  pipelines; no JDK, no Gradle.
- `images/node/Dockerfile` — Node variant build definition.
- `scripts/install-node-toolchain.sh` — verifies node/npm/npx/corepack and the
  node-gyp build deps are present, and enables corepack.
- `mandoc` in the Alpine base packages: the apk build of the AWS CLI renders
  `aws <cmd> help` through a system pager instead of bundling its own docs, so
  `aws ecr help` — asserted by the smoke test — failed without it.

- **GraalVM CE for JDK 21 variant** published under `-graalvm` tag suffix
  (`:vX.Y.Z-graalvm`, `:graalvm` rolling tag on `main`). Base image
  `ghcr.io/graalvm/jdk-community:21` (Oracle Linux 9 / glibc). Ships
  `native-image` preinstalled for `nativeCompile` pipelines.
- **KrakenD variant** published under `-krakend` tag suffix
  (`:vX.Y.Z-krakend`, `:krakend` rolling tag on `main`). Base image
  `alpine:3.21` with multi-stage COPY of the KrakenD CLI from
  `krakend:${KRAKEND_VERSION}` (2.13.4) and the Go toolchain from
  `golang:${GO_VERSION}-alpine` (1.25.7). Adds `build-base` + `binutils-gold`
  + `make` for `go build -buildmode=plugin` (custom KrakenD Go plugins).
  No JDK or Gradle.
- `images/graalvm/Dockerfile` — GraalVM variant build definition.
- `images/krakend/Dockerfile` — KrakenD variant build definition (multi-stage).
- `scripts/install-base-packages-ol.sh` — microdnf-based base-package install
  for Oracle Linux 9, enables EPEL for `wireguard-tools`.
- `scripts/install-docker-cli-ol.sh` — Docker CE repo + microdnf install of
  `docker-ce-cli` + `docker-buildx-plugin` on OL9.
- `scripts/cleanup-ol.sh` — dnf/yum cache cleanup variant.
- `scripts/install-native-image.sh` — verifies `native-image` is present on
  the GraalVM variant (preinstalled in GraalVM 21+; `gu` is gone).
- `scripts/install-krakend.sh` — verifies the `krakend` CLI binary COPYed
  from `krakend:${KRAKEND_VERSION}` is on PATH (KrakenD variant).
- `scripts/install-go.sh` — verifies the Go toolchain COPYed from
  `golang:${GO_VERSION}-alpine` is on PATH, plus `gcc` / `ld.gold` for
  `-buildmode=plugin` builds (KrakenD variant).
- `CI_VARIANT` env var baked into each image; `smoke-test.sh` gates
  variant-specific assertions (`java`/`gradle` on JDK + GraalVM,
  `native-image` on GraalVM, `krakend`/`go`/`make` on KrakenD).
- New OCI labels: `io.codehunters.variant`, `io.codehunters.contents.libc`,
  `io.codehunters.contents.base`, `io.codehunters.contents.native-image` (GraalVM only),
  `io.codehunters.contents.krakend` + `io.codehunters.contents.go` (KrakenD only).

### Fixed
- **AWS CLI no longer installs on current Alpine (all musl variants).** The
  glibc PyInstaller bundle pinned to 2.17.65 and run under gcompat dies at
  image build time: `posix_fallocate64: symbol not found` on Alpine 3.23
  (`node:20-alpine`), `pthread_attr_setaffinity_np: symbol not found` on 3.24
  (`eclipse-temurin:21-jdk-alpine`). Each gcompat release drifts further from
  what the bundle needs, and one pin per Alpine release was never going to
  hold. `scripts/install-aws-cli.sh` now installs `aws-cli` from the Alpine
  community repository on musl — a real musl build, no shim — and keeps the
  official bundle for glibc. Set `AWS_CLI_FROM_BUNDLE=1` to force the old path.
  This was latent for the JDK and KrakenD variants too: they build today only
  because they have not been rebuilt since Alpine moved.

### Changed
- **Repository layout**: top-level `Dockerfile` moved to
  `images/jdk/Dockerfile`. Build context remains the repo root so both
  variants share `scripts/`.
- `scripts/install-base-packages.sh`, `scripts/install-docker-cli.sh`,
  `scripts/cleanup.sh` are now thin dispatchers that detect the distro
  (`/etc/alpine-release` vs `/etc/os-release`) and exec the matching
  `*-alpine.sh` or `*-ol.sh` variant.
- `scripts/install-aws-cli.sh` now detects libc (musl vs glibc) and chooses
  the AWS CLI version accordingly — pins `2.17.65` on musl (gcompat ceiling),
  defaults to `latest` on glibc. Removes the gcompat workaround from the
  GraalVM image build path.
- `build-publish.yml` rewritten as a `variant: [jdk, graalvm, krakend]`
  matrix. Each variant builds + smokes amd64 + arm64 independently with
  scoped GHA cache (`jdk-amd64`, `graalvm-arm64`, `krakend-amd64`, etc.) and
  publishes a per-variant multi-arch manifest. `metadata-action` adds the
  `-graalvm` / `-krakend` suffix via `flavor:` for the non-default jobs.
- `pr-validation.yml` rewritten with hadolint and build+smoke matrices over
  all three variants. ShellCheck still scans all of `scripts/` once.
- `.github/dependabot.yml` now uses `directories:` (plural) and tracks
  `/images/jdk`, `/images/graalvm`, `/images/krakend`.
- Workflow path filters changed from `Dockerfile` to `images/**`.

### Removed
- Top-level `Dockerfile` (replaced by `images/jdk/Dockerfile`).

### Initial scaffolding (pre-variant-split)
- Initial Dockerfile based on `eclipse-temurin:21-jdk-alpine`.
- Install scripts: base packages, Gradle 9.0, AWS CLI v2, Docker CLI + buildx.
- Smoke test script asserting all tools resolve and report expected versions.
- `build-publish.yml` workflow — multi-arch (amd64+arm64) GHCR publish with
  semver, sha, and latest tag strategy.
- `pr-validation.yml` workflow — hadolint + shellcheck + amd64 smoke test.
- Dependabot configuration for `docker` and `github-actions` ecosystems.
