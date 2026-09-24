# Changelog

All notable changes to this project will be documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.0] - 2026-09-24

### Changed
- **`develop` is now the default branch; `main` is the release branch.** Same
  shape as `ci-templates`: work lands in `develop`, merging it into `main`
  publishes, and a `v*` tag on `main` cuts a version. Pull request validation
  runs for both.

  The rolling tags had to be made explicit to survive this. The shared publish
  workflow enables them when the push is on the repository's *default* branch —
  correct for a single-branch repo, wrong once `main` stops being the default.
  Left implicit, `:latest`, `:jdk25`, `:graalvm` and the rest would simply stop
  moving: no error, no failed job, just consumers on a rolling tag frozen on an
  old digest. `build-publish.yml` now passes `push_rolling` on
  `refs/heads/main` itself. Tag pushes stay excluded, as documented.

  `:latest` therefore moves when `develop` reaches `main` rather than on every
  merge.
- **Every workflow now comes from `ci-templates`.** `pr-validation.yml`,
  `build-publish.yml` and `security-scan.yml` were 751 lines of CI living in
  this repository; they are now 189 lines of caller against
  `shared-validate-image-pr`, `shared-build-publish-image` and
  `shared-scan-published-images`. `cleanup-packages.yml` already called out and
  moves to the same release, so all four pin one version of ci-templates
  instead of two.

  Two of those reusable workflows are new — the pre-merge gate and the weekly
  rescan had no template, so this is not a file move. They were added in
  ci-templates v1.5.0, with a self-test that runs the validation workflow
  end to end.

  Pinned by commit SHA rather than `@v1`: a reusable workflow resolves at call
  time, so a floating alias means any release of ci-templates changes what runs
  here with no commit in this repository.

  Behaviour is unchanged, including the two things worth losing in a migration:
  pull requests still validate **both** architectures, and arm64 still builds on
  a native runner rather than QEMU — the shared workflow takes `runner_arm64`
  for exactly this. Validating only amd64 is what let the TARGETARCH shadowing
  bug reach `main` behind a green pull request.

  `scripts/` stays local. It is this repository's own knowledge, and
  `check-pins.sh` reaches the shared workflow as `gate_command` — a string it
  runs without knowing what it does.

- **Java 27 is out of scope, and not "pending upstream".** The 1.2.0 note said
  it was excluded because Temurin published no image; the durable reason is that
  27 is not an LTS. This repository tracks LTS majors only — 21 today, 25
  beside it, 29 when it ships in September 2027 — so 26, 27 and 28 are never
  candidates regardless of what Temurin publishes. Nothing to wait for.

### Security
- **Every Debian- and Alpine-derived base digest refreshed.** Five rebuilds of
  the same tags, taken straight from the registry rather than from a version
  bump: `eclipse-temurin:21-jdk-alpine`, `eclipse-temurin:21-jre-alpine`,
  `krakend:2.13.11`, `alpine:3.24` and `debian:12-slim`. A digest-pinned `FROM`
  is frozen against exactly this — the upstream tag moves when its distro
  patches, and the pin does not follow it — so a rebuild is the only way the
  patches reach these images. `GO_VERSION` is untouched: the KrakenD bump is a
  rebuild of 2.13.11, not a new release, so the plugin ABI pin still holds.

## [1.2.0] - 2026-09-18

### Added
- **Java 25 published alongside Java 21, as three new variants.**
  `-jdk25` (Temurin JDK 25 + Gradle), `-graalvm25` (GraalVM CE for JDK 25 with
  `native-image`) and `-java25-runtime` (Temurin JRE 25, non-root, tini). All
  three are multi-arch and built from the same commit and semver as the rest,
  so moving a repository to Java 25 is a suffix change per stage, not a version
  bump.

  **Java 21 remains the default and is untouched.** The unsuffixed tags —
  `:latest`, `:vX.Y.Z` — are still JDK 21, so no existing consumer changes.

  Each major lives in its own directory rather than behind an `ARG` over the
  `FROM`. The `FROM`s are literal precisely so Dependabot can see and update
  the digests, and `FROM ${JAVA_IMAGE}` would hide both majors from it.

- **Every Java image asserts the major it claims.** The images now carry
  `CI_JAVA_MAJOR`, and the smoke tests fail if the running JVM disagrees with
  it. Two majors built from near-identical directories make one specific
  mistake likely — a `FROM` edited in one copy and a label edited in the other
  — and `check-pins.sh` cannot catch it, because each file stays internally
  consistent. Verified in both directions: a 25 image claiming 21 fails, and an
  image with the variable unset fails rather than passing silently.

- **Java 27 was requested and is not included: it does not exist upstream.**
  Temurin publishes no 27 image on Docker Hub, early-access included, and
  GraalVM's `native-image-community` stops at 25. There is no base to build on.
  Adding it later means copying the `25` directories and their matrix rows.

### Security
- **KrakenD CI image bumped to 2.13.11, clearing 39 fixable HIGH advisories.**
  The pinned 2.13.4 vendored `golang.org/x/crypto` v0.49.0, `x/net` v0.52.0 and
  a go1.25.9 stdlib, all of which carry patched CVEs. 2.13.11 ships x/crypto
  v0.56.0 on a go1.26.8 stdlib and scans clean at HIGH/CRITICAL with
  `--ignore-unfixed`. `CVE-2026-56854` is therefore dropped from
  `.trivyignore.yaml`: the exception was written when no KrakenD release linked
  a fixed x/crypto, and one now does.

### Fixed
- **The GraalVM major ignore rule matched nothing.** It spelled the image
  `ghcr.io/graalvm/native-image-community`, but Dependabot strips the registry
  host from a Docker dependency name, so the rule written to suppress major
  bumps never fired — PR #22 (21 → 24) sat open for two weeks against a policy
  that already forbade it. The name now carries no host. Every other entry was
  unaffected: `eclipse-temurin`, `node`, `golang`, `krakend`, `alpine` and
  `debian` all appear in a `FROM` without one.

### Changed
- **`GO_VERSION` is now derived from the KrakenD release, not bumped on its
  own.** Go plugins must be compiled with the exact toolchain the gateway
  binary was built with, so the Go pin moves to 1.26.8 alongside KrakenD
  2.13.11 — read off the binary with `go version -m`, and documented as such in
  the Dockerfile. A standalone Go bump (Dependabot proposed 1.27.1) produces
  `.so` files the runtime refuses to load, with nothing in CI to catch it.
- Base image and action pins refreshed: `nginx` 1.31.5 → 1.31.6-alpine (web
  runtime), `docker/build-push-action` 6.19.2 → 7.3.0,
  `docker/setup-buildx-action` 3.12.0 → 4.3.0, `docker/metadata-action`
  5.10.0 → 6.2.0, `github/codeql-action/upload-sarif` 4.37.9 → 4.38.0.

## [1.1.0] - 2026-09-03

### Fixed
- **Every image reference in the README was unusable.** The org was
  `ghcr.io/codehunters/...`, but GHCR lowercases `github.repository`, so the
  path is `codehunters-io`. The tags carried a `v` the registry never sees —
  `docker/metadata-action` strips it, so `v1.0.0` publishes as `1.0.0`. Copying
  any example gave an image that does not exist. Also corrects the package
  settings URL, which pointed at `/users/codehunters` for what is an org.

### Changed
- **Dependabot no longer proposes major bumps for the pinned runtimes.** The
  restructure into `images/ci/` and `images/runtime/` widened its coverage from
  three directories to eight, and it immediately opened majors for
  `eclipse-temurin` (21→25), `graalvm/native-image-community` (21→25), `node`
  (20→26) and `debian` (12→13). Three of those contradict a version this repo
  states in its tags, labels and docs; the fourth would desynchronise the libz
  staged into the native image from the distroless base it is copied into. All
  four are now ignored at major level, each with its reason in the config.

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

### Added
- **Runtime base images**, a second family alongside the CI ones. `-java-runtime`
  (Temurin JRE 21, uid 10001, tini), `-node-runtime` (Node 20, uid 1000, no
  compiler), `-web-runtime` (nginx unprivileged on 8080, SPA fallback, security
  headers, `/healthz`) and `-native-runtime` (distroless + `libz`, uid 65532, no
  shell) — for applications to inherit from, where the CI images explicitly must
  not be used. All non-root, none carrying a build toolchain, a Docker CLI or an
  AWS CLI.
- `scripts/smoke-test-runtime.sh` asserts both what a runtime base owes its app
  and what it must *not* carry; `scripts/smoke-test-native.sh` asserts the
  shell-less image from the host, since nothing can be executed inside it.
- `scripts/run-smoke.sh` dispatches per family — baked-in script for CI images,
  mounted for runtime ones, host-side for distroless.

### Changed
- **`images/` is now split into `images/ci/` and `images/runtime/`.** Build
  contexts, the Dependabot directory list and both workflow matrices follow.
  Published CI tags are unchanged.

### Fixed
- **Rolling tags were published doubled**: `graalvm-graalvm`, `krakend-krakend`,
  `node-node`. `flavor.suffix` applies to every tag metadata-action emits,
  including the `type=raw` rolling tag whose value already names the variant.
  The entry now sets `suffix=` to opt out. `latest` was unaffected because the
  JDK variant has no suffix.

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
