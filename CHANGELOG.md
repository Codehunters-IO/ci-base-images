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
- **Every variant failed to publish on `arm64`.** `pr-validation.yml` builds
  amd64 only, so pull requests went green while `build-publish.yml` — which
  builds both — failed on main for all four images. Two causes:
  `ARG TARGETARCH=amd64` shadowed the value BuildKit injects (an ARG only
  receives it when declared *without* a default), so the arm64 GraalVM build
  downloaded the x86_64 AWS CLI bundle and died on `/tmp/aws/dist/aws: No such
  file or directory`; and the musl variants failed the `iptables` smoke
  assertion under QEMU emulation.

### Removed
- **`iptables` and `iproute` dropped from every variant.** They were WireGuard's
  dependencies, kept when it was removed on the grounds that they were not
  exclusive to it. Nothing else invokes them — the only reference left was the
  smoke test asserting they exist, and under QEMU that assertion was blocking
  every arm64 publish.

### Security
- **AWS CLI bundle signature is now verified, and the check is enforced.**
  `AWS_CLI_VERIFY_GPG` defaults to `1`. The key is vendored at
  `scripts/aws-cli-pgp.asc` instead of fetched from
  `https://awscli.amazonaws.com/aws-cli-pgp.txt`, which 404s — so the previous
  opt-in path could not have worked — and which, being the host that also
  serves the artifact, would not have been worth much if it had. Verification
  requires a `VALIDSIG` line for `FB5DB77FD5C118B80511ADA8A6310ACC4672475C`
  rather than gpg's exit status, which is `0` for a good signature by any key
  in the keyring and `0` for an expired key; AWS has signed with an expired key
  since 2026-07-07.
- **GraalVM variant pins `AWS_CLI_VERSION=2.36.32`** instead of tracking
  `latest`, so a rebuild fetches the same artifact twice.

### Fixed
- **GraalVM variant never had `native-image`, and could not install WireGuard.**
  Two problems in the same build step. `jdk-community:21` is a plain JDK — the
  tool is not in `$JAVA_HOME/bin` — so the base moved to
  `ghcr.io/graalvm/native-image-community:21`, which carries it. And
  `install-base-packages-ol.sh` installed EPEL from a Fedora RPM URL, which
  microdnf rejects outright (`No package matches 'https://...'`); the EPEL step
  is gone because `wireguard-tools` is in `ol9_appstream` already. `PATH` now
  includes `$JAVA_HOME/bin`, where `native-image` and `javac` live.
- **`java` and `javac` were not on `PATH` in the JDK variant.** The Dockerfile
  sets `PATH` outright rather than prepending to it, and the value omitted
  `$JAVA_HOME/bin` — so the image shipped a JDK that nothing could invoke. The
  smoke test caught it as soon as the build got far enough to run:
  `[FAIL] java`. `/opt/java/openjdk/bin` restored to the front of `PATH`.
- **KrakenD variant failed with exit code 141 after printing the linker
  version.** `install-go.sh` ended on `ld.gold --version | head -1`; `head`
  exits after one line, the writer takes SIGPIPE, and `set -o pipefail` turns
  128+13 into a failed build. Version banners are now captured and trimmed
  without a pipe. The same pattern in `smoke-test.sh` (`java -version`,
  `native-image --version`, `krakend version`) was replaced with
  `sed -n '1s/^/  /p'`, which reads to EOF and cannot signal the writer.
- **GraalVM variant could not install base packages.** `install-base-packages-ol.sh`
  asked microdnf for `coreutils`, but the GraalVM base image ships
  `coreutils-single`, and the two packages conflict by design — one multi-call
  binary versus the split set. microdnf refused the swap with
  `Could not depsolve transaction ... cannot install the best candidate for the
  job`. Dropped from the list; `coreutils-single` already provides every binary
  the image needs, and the script's own verify loop covers them.
- **Gradle never installed at version `9.0` — that release does not exist.**
  Gradle 9 is published as `9.0.0`; `9.0` names only the milestones. The
  distribution URL `gradle-9.0-bin.zip` happens to answer 200, so the download
  looked fine, but `gradle-9.0-bin.zip.sha256` is a 404 and the checksum step
  failed the build with `curl: (22)`. Pinned to `9.0.0`, which serves both the
  zip and its checksum and is the version `services.gradle.org/versions/all`
  actually lists. Affects the JDK and GraalVM variants.
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

### Removed
- **WireGuard tools are no longer installed in any variant.** Nothing consumed
  them from here: `shared-deploy-ec2-vpn.yml` in `ci-templates` installs
  `wireguard-tools` on the runner and brings the tunnel up outside any job
  container, so `deploy_target: ec2-vpn` is unaffected. The `wg` / `wg-quick`
  smoke-test checks, the `--cap-add=NET_ADMIN` examples in the README, and the
  `wg-quick` justification for running as `root` in SECURITY.md go with them.

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
