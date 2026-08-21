# ci-base-images

Pre-baked CI base images for `codehunters-ms-*` Java microservice and
`codehunters/tickets` contract pipelines. Replaces per-run installs
(`setup-java`, `setup-gradle`, `setup-node`, `apt-get install wireguard`,
AWS CLI download) with a single `container:` directive in GitHub Actions.

Four variants are published to `ghcr.io/codehunters/ci-base-images`:

| Variant     | Tag suffix    | Base image                              | libc  | Approx size | Use case                                  |
|-------------|---------------|-----------------------------------------|-------|-------------|-------------------------------------------|
| **JDK**     | _(none)_      | `eclipse-temurin:21-jdk-alpine`         | musl  | ~450 MB     | `codehunters-ms-*` build/test/deploy (default)  |
| **GraalVM** | `-graalvm`    | `ghcr.io/graalvm/jdk-community:21`      | glibc | ~1.1 GB     | `nativeCompile` / `native-image` jobs     |
| **KrakenD** | `-krakend`    | `alpine:3.21` + `krakend` + `golang`    | musl  | ~700 MB     | `codehunters-gw-krakend` gateway pipelines      |
| **Node**    | `-node`       | `node:20.20.2-alpine`                   | musl  | ~210 MB     | Hardhat/Solidity + TypeScript SDK pipelines |

> **CI-only images.** Run as `root`. Do **not** use as a runtime base for
> application containers. The `io.codehunters.usage=ci-only` label flags misuse.

Architectures for every variant: `linux/amd64`, `linux/arm64` (multi-arch manifest).

---

## What's inside

Common to **all** variants:

| Tool             | Version             | Source                              |
|------------------|---------------------|-------------------------------------|
| AWS CLI          | v2 (musl: 2.17.65 pinned; glibc: latest) | awscli.amazonaws.com (TLS)|
| Docker CLI       | distro repo         | apk (Alpine) / docker-ce (OL9)      |
| Docker Buildx    | distro repo         | apk / docker-buildx-plugin          |
| WireGuard tools  | distro repo         | apk (Alpine) / EPEL (OL9)           |
| GNU userland     | coreutils, gawk, sed, grep | apk / microdnf               |
| Misc             | bash, jq, bc, curl, wget, git, openssh, iptables, iproute, gnupg, tzdata | apk / microdnf |

Variant-specific tooling:

| Tool / runtime    | JDK | GraalVM | KrakenD | Node | Source                           |
|-------------------|:---:|:-------:|:-------:|:----:|----------------------------------|
| Temurin JDK 21    | ✅  | ❌      | ❌      | ❌   | `eclipse-temurin:21-jdk-alpine`  |
| GraalVM CE JDK 21 | ❌  | ✅      | ❌      | ❌   | `ghcr.io/graalvm/jdk-community:21` |
| `native-image`    | ❌  | ✅      | ❌      | ❌   | preinstalled in GraalVM 21+      |
| Gradle CLI 9.0    | ✅  | ✅      | ❌      | ❌   | services.gradle.org (SHA-256 pinned) |
| KrakenD CLI       | ❌  | ❌      | ✅      | ❌   | `krakend:${KRAKEND_VERSION}` (multi-stage COPY) |
| Go toolchain      | ❌  | ❌      | ✅      | ❌   | `golang:${GO_VERSION}-alpine` (multi-stage COPY) |
| `build-base`      | ❌  | ❌      | ✅      | ✅   | apk (Go plugins on KrakenD; node-gyp on Node) |
| `binutils-gold` (for `go build -buildmode=plugin`) | ❌ | ❌ | ✅ | ❌ | apk |
| `make`            | ❌  | ❌      | ✅      | ✅   | apk                              |
| Node.js 20 + npm  | ❌  | ❌      | ❌      | ✅   | `node:${NODE_VERSION}-alpine`    |
| corepack (pnpm/yarn on demand) | ❌ | ❌ | ❌ | ✅ | bundled with Node 20, enabled at build |
| `python3` (node-gyp) | ❌ | ❌     | ❌      | ✅   | apk                              |

---

## Image tags

JDK variant (default — no suffix):

| Tag                  | Trigger                                    | Use case                  |
|----------------------|--------------------------------------------|---------------------------|
| `vX.Y.Z`             | Git tag `v*`                                | Production pipelines (PIN)|
| `vX.Y`, `vX`         | Git tag `v*` (rolling minor/major)         | Tolerant rolling updates  |
| `latest`             | Push to `main`                              | Development pipelines     |
| `sha-<short>`        | Every build                                 | Reproducible debugging    |
| `main`               | Push to `main`                              | Bleeding edge             |

GraalVM variant (`-graalvm` suffix):

| Tag                     | Trigger                                    | Use case                          |
|-------------------------|--------------------------------------------|-----------------------------------|
| `vX.Y.Z-graalvm`        | Git tag `v*`                                | Production native-image pipelines |
| `vX.Y-graalvm`, `vX-graalvm` | Git tag `v*`                          | Tolerant rolling updates          |
| `graalvm`               | Push to `main`                              | Development native-image pipelines|
| `sha-<short>-graalvm`   | Every build                                 | Reproducible debugging            |
| `main-graalvm`          | Push to `main`                              | Bleeding edge                     |

KrakenD variant (`-krakend` suffix):

| Tag                     | Trigger                                    | Use case                          |
|-------------------------|--------------------------------------------|-----------------------------------|
| `vX.Y.Z-krakend`        | Git tag `v*`                                | Production gateway pipelines      |
| `vX.Y-krakend`, `vX-krakend` | Git tag `v*`                          | Tolerant rolling updates          |
| `krakend`               | Push to `main`                              | Development gateway pipelines     |
| `sha-<short>-krakend`   | Every build                                 | Reproducible debugging            |
| `main-krakend`          | Push to `main`                              | Bleeding edge                     |

Node variant (`-node` suffix):

| Tag                     | Trigger                                    | Use case                          |
|-------------------------|--------------------------------------------|-----------------------------------|
| `vX.Y.Z-node`           | Git tag `v*`                                | Production contract pipelines     |
| `vX.Y-node`, `vX-node`  | Git tag `v*`                                | Tolerant rolling updates          |
| `node`                  | Push to `main`                              | Development contract pipelines    |
| `sha-<short>-node`      | Every build                                 | Reproducible debugging            |
| `main-node`             | Push to `main`                              | Bleeding edge                     |

**Production rule:** pin a semver tag (e.g. `:v1.0.0`, `:v1.0.0-graalvm`,
`:v1.0.0-krakend`, `:v1.0.0-node`). Never `:latest` / `:graalvm` / `:krakend` /
`:node` in release/prod paths. All four variants are always built from the same
commit and share the same semver — pick the variant by suffix, the version by
number.

---

## Usage in a consumer workflow

### JDK variant (default — build / test / deploy)

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/codehunters/ci-base-images:v1.0.0
    steps:
      - uses: actions/checkout@v5

      - name: Build with Gradle
        env:
          GH_PACKAGES_USERNAME: ${{ secrets.GH_PACKAGES_USERNAME }}
          GH_PACKAGES_TOKEN: ${{ secrets.GH_PACKAGES_TOKEN }}
        run: ./gradlew clean build -x test --no-daemon --build-cache --parallel
```

`actions/setup-java@v5` and `gradle/actions/setup-gradle@v4` are dropped — the
image already has Temurin 21 and Gradle 9.0 on `$PATH`.

### GraalVM variant (native-image)

```yaml
jobs:
  native-build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/codehunters/ci-base-images:v1.0.0-graalvm
    steps:
      - uses: actions/checkout@v5

      - name: Build native image
        run: ./gradlew nativeCompile --no-daemon --build-cache
```

### KrakenD variant (gateway build + plugin compile + config check)

```yaml
jobs:
  gateway-build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/codehunters/ci-base-images:v1.0.0-krakend
    steps:
      - uses: actions/checkout@v5

      - name: Validate Flexible Config
        run: |
          FC_ENABLE=1 \
          FC_SETTINGS="config/settings" \
          krakend check -d -t -c config/krakend.tmpl

      - name: Build custom Go plugins
        run: |
          for plugin in jwt-headers ip-resolver trace-context; do
            (cd plugins/$plugin && go build -buildmode=plugin -o $plugin.so .)
          done

      - name: Build + push gateway image
        run: docker buildx build --platform linux/amd64 --push -t $ECR/codehunters-gw-krakend:$GITHUB_SHA .
```

### Node variant (Hardhat contracts + TypeScript SDK)

```yaml
jobs:
  contracts:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/codehunters/ci-base-images:v1.0.0-node
    steps:
      - uses: actions/checkout@v5

      - name: Install dependencies
        run: npm ci

      - name: Contracts
        run: npx hardhat test

      - name: Coverage gate
        run: npm run coverage

      - name: SDK
        run: npm run test:sdk
```

No `actions/setup-node` and no `actions/cache`: the Node version is baked into
the tag, so a repository that pins `engines: ">=20 <21"` cannot silently drift
onto a runner default. `npm ci` still resolves from the lockfile.

### WireGuard VPN deploy job (either variant)

```yaml
deploy:
  runs-on: ubuntu-latest
  container:
    image: ghcr.io/codehunters/ci-base-images:v1.0.0
    options: --cap-add=NET_ADMIN
  steps:
    - name: Bring up WireGuard
      run: |
        echo "${WG_CONF}" | sudo tee /etc/wireguard/wg0.conf
        wg-quick up wg0
```

`NET_ADMIN` capability is required for `wg-quick` to install routes inside the
container.

---

## End-to-end example: deploy a `codehunters-ms-*` service

Canonical pattern used by `codehunters-ms-payment`, `codehunters-ms-auth`,
`codehunters-ms-raffles`, `codehunters-ms-file-share`. The per-service repo delegates to
the shared reusable workflow in `codehunters/ci-templates`, which runs every stage
(build, test, ECR publish, EC2 deploy over WireGuard) inside this image.

### Develop pipeline — build + test + coverage + release PR

```yaml
# .github/workflows/develop-pipeline.yml in codehunters-ms-foo
name: Develop Pipeline
on:
  push:
    branches: [develop]

permissions:
  contents: write
  checks: write
  pull-requests: write

jobs:
  pipeline:
    if: ${{ !contains(github.event.head_commit.message, '[skip ci]') }}
    uses: codehunters/ci-templates/.github/workflows/java-main-pipeline.yml@main
    with:
      run_build: true
      run_test: true
      run_coverage: true
      run_owasp: true
      notify_on_failure: true
      notify_on_release: true
      run_cleanup: true
      run_release: true
      release_target_branch: 'main'
    secrets: inherit
```

### Main pipeline — deploy to EC2 over VPN on merge to `main`

```yaml
# .github/workflows/main-pipeline.yml in codehunters-ms-foo
name: Deploy to Main
on:
  push:
    branches: [main]

permissions:
  contents: write
  checks: write
  pull-requests: write
  id-token: write

jobs:
  pipeline:
    if: ${{ !contains(github.event.head_commit.message, '[skip ci]') }}
    uses: codehunters/ci-templates/.github/workflows/java-main-pipeline.yml@main
    with:
      run_build: true
      run_test: true
      run_artifact: true
      run_deploy: true
      deploy_target: 'ec2-vpn'
      environment: 'develop'
      notify_on_failure: true
      notify_on_deploy: true
      run_tag: true
    secrets: inherit
```

### Where this image plugs in

`codehunters/ci-templates/.github/workflows/java-main-pipeline.yml` sets:

```yaml
container:
  image: ghcr.io/codehunters/ci-base-images:v1.0.0
  options: --cap-add=NET_ADMIN   # required by wg-quick on deploy_target=ec2-vpn
```

Bumping that single pin in `ci-templates` rolls every `codehunters-ms-*` pipeline to
the new image. No `setup-java`, no `setup-gradle`, no `apt-get install
wireguard`, no AWS CLI download — every tool is already on `$PATH`.

| Pipeline stage          | Tool used         | From this image             |
|-------------------------|-------------------|-----------------------------|
| Compile + test          | `java`, `gradle`  | yes                         |
| OWASP dep-check         | `gradle` plugin   | yes                         |
| Build OCI image         | `docker buildx`   | yes                         |
| ECR login + push        | `aws`, `docker`   | yes                         |
| Open release PR         | `gh`/`git`        | yes (`git` baked in)        |
| Connect to private VPC  | `wg`, `wg-quick`  | yes (needs `NET_ADMIN`)     |
| Drive remote deploy     | `ssh`, `bash`     | yes                         |
| Patch compose file      | `sed`, `awk`      | yes (GNU userland)          |

Typical saving: **~90 s** per job vs. the legacy `setup-java + setup-gradle +
apt-get + curl awscli` sequence.

### Native-image variant

Services that run `./gradlew nativeCompile` pin the `-graalvm` suffix tag in
their `ci-templates` invocation. Only the build job needs the larger GraalVM
image; deploy stays on the JDK variant (`wg`, `ssh`, `aws`, `docker` are
identical across variants).

### KrakenD gateway (`codehunters-gw-krakend`)

The gateway repo uses a separate reusable workflow
(`krakend-main-pipeline.yml`) that runs every stage inside the KrakenD
variant of this image: `krakend check` (Flexible Config validation),
`go build -buildmode=plugin` for the custom plugins (`jwt-headers`,
`ip-resolver`, `trace-context`), `docker buildx` for the gateway image, and
WireGuard + SSH for the EC2 deploy.

```yaml
# .github/workflows/develop-pipeline.yml in codehunters-gw-krakend
name: Develop Pipeline
on:
  push:
    branches: [develop]

permissions:
  contents: write
  checks: write
  pull-requests: write
  packages: write

jobs:
  pipeline:
    if: ${{ !contains(github.event.head_commit.message, '[skip ci]') }}
    uses: codehunters/ci-templates/.github/workflows/krakend-main-pipeline.yml@main
    with:
      run_commit_lint: false
      run_build: true
      run_test: true
      run_artifact: false
      run_deploy: false
      run_cleanup: false
      run_release: true
      release_target_branch: 'main'
    secrets: inherit
```

```yaml
# .github/workflows/main-pipeline.yml in codehunters-gw-krakend
name: Deploy to Main
on:
  push:
    branches: [main]

permissions:
  contents: write
  checks: write
  pull-requests: write
  packages: write

jobs:
  pipeline:
    if: ${{ !contains(github.event.head_commit.message, '[skip ci]') }}
    uses: codehunters/ci-templates/.github/workflows/krakend-main-pipeline.yml@main
    with:
      run_commit_lint: false
      run_build: true
      run_test: true
      run_artifact: true
      run_deploy: true
      run_cleanup: false
      run_release: false
      deploy_target: 'ec2-vpn'
      environment: 'develop'
      release_target_branch: 'main'
    secrets: inherit
```

Inside `krakend-main-pipeline.yml`:

```yaml
container:
  image: ghcr.io/codehunters/ci-base-images:v1.0.0-krakend
  options: --cap-add=NET_ADMIN
```

One pin bumps every KrakenD stage at once. The KrakenD CLI version and Go
toolchain are baked into the image (`KRAKEND_VERSION` + `GO_VERSION` build
args); upgrading them requires a new image release, which avoids drift
between gateway runtime (`krakend:2.13.4`) and CI plugin builds.

---

## Base image rationale

### JDK variant — `eclipse-temurin:21-jdk-alpine`

Chosen for compactness over `:21-jdk-jammy`. Trade-off: musl libc. AWS CLI v2
ships as a glibc-linked static bundle, so `gcompat` is installed to provide a
glibc shim. AWS CLI is pinned to **2.17.65** on musl — the last release built
on Python 3.11. v2.18+ bundles Python 3.14 which needs the `dladdr1` glibc
symbol absent in gcompat.

The only AWS command exercised in CI is `aws ecr get-login-password`, which
works through `gcompat`. A smoke test catches regressions before publish.

| Candidate                            | Reason rejected                                   |
|--------------------------------------|---------------------------------------------------|
| `eclipse-temurin:21-jdk-jammy`       | ~50 MB larger than alpine; no functional gain     |
| `amazoncorretto:21-alpine`           | Vendor-inconsistent (workflows specify `temurin`) |
| `alpine:3.20` + manual JDK install   | Saves only ~5 MB; adds lifecycle burden           |
| `debian:bookworm-slim` + manual JDK  | Larger than alpine after tooling added            |
| `distroless`                         | No shell — breaks CI shell scripts                |

### GraalVM variant — `ghcr.io/graalvm/jdk-community:21`

GraalVM Community Edition does not publish an Alpine/musl image. Oracle Linux
9 (glibc) is the official base. `native-image` ships preinstalled in GraalVM
for JDK 21 (the `gu` component installer was removed in GraalVM 23.x).

On glibc, the AWS CLI gcompat workaround is unnecessary, so `install-aws-cli.sh`
defaults to the latest v2 release on this variant. WireGuard tools come from
EPEL (`epel-release-latest-9`).

| Candidate                                                | Reason rejected                                   |
|----------------------------------------------------------|---------------------------------------------------|
| `container-registry.oracle.com/graalvm/jdk:21`           | Commercial Oracle GraalVM; licence restrictions   |
| `ghcr.io/graalvm/native-image-community:21` (older base) | Superseded by `jdk-community` (includes `native-image`) |
| Custom Alpine + GraalVM tarball                          | No official musl build; binary-compat risk        |

### KrakenD variant — `alpine:3.21` + multi-stage COPY

Alpine 3.21 is the base; the `krakend` binary is COPYed from the official
`krakend:${KRAKEND_VERSION}` image and the Go toolchain from
`golang:${GO_VERSION}-alpine`. Three reasons for this shape:

1. **ABI compatibility** for `go build -buildmode=plugin`: the runtime image
   (`krakend:2.13.4`) is built against a specific Go version (1.25.x at the
   time of writing). Plugin `.so` files must be built with the **exact same**
   Go version or they fail to load. apk's Go is typically behind — multi-stage
   COPY pins the version deterministically.
2. **Single CI container** for the full gateway pipeline: KrakenD CLI
   (`krakend check`), Go plugin compile (`-buildmode=plugin` needs
   `binutils-gold`), `docker buildx` (gateway image build), `aws ecr` push,
   and `wg`/`ssh` for EC2 deploy — no per-job tool install.
3. **No JDK/Gradle** in this variant — gateway repos don't need them; saves
   ~250 MB versus stuffing them into the JDK base.

| Candidate                                          | Reason rejected                                          |
|----------------------------------------------------|----------------------------------------------------------|
| `krakend:2.13.4` directly as CI base               | Lacks Go, docker, aws, wg, ssh — defeats the purpose     |
| `golang:1.25.7-alpine` directly as CI base         | Lacks krakend CLI, aws v2, docker, wg                    |
| Extending the JDK variant with Go + KrakenD        | ~1.2 GB image; pulls Temurin for no gateway purpose      |
| `debian:bookworm-slim` + apt Go                    | apt Go = 1.21; ABI mismatch with `krakend/builder` (1.25)|

### Node variant — `node:20.20.2-alpine`

Node **20**, not the newest LTS: the consumers pin it (`.nvmrc`,
`engines: ">=20 <21"`) because their Hardhat toolchain and their exactly-pinned
crypto dependencies decide bytes that get signed and anchored on a blockchain.
An image that led the consumers here would silently move the floor under them.
The version is an `ARG` and the tag carries it, so bumping is one deliberate
edit, not a rebuild side effect.

`build-base` and `python3` are in this variant for node-gyp: a dependency
published without a `linux-musl` prebuild compiles from source during `npm ci`,
and an image that cannot do that breaks every consumer at once, in a step that
reads as a dependency problem rather than an image problem.

corepack is enabled but no package manager is downloaded at build time — pnpm
and yarn resolve from the repository's own `packageManager` field on first use,
so the image stays agnostic about a choice each repository already made.

| Candidate                                     | Reason rejected                                              |
|-----------------------------------------------|--------------------------------------------------------------|
| `actions/setup-node` on a plain runner        | What this repository exists to replace: a download per job    |
| Extending the JDK variant with Node           | ~660 MB to run `npm ci`; no contract pipeline needs a JVM     |
| `node:20-bookworm-slim` (glibc)               | Would need a third distro branch in every install script      |
| `node:22-alpine`                              | Consumers pin `<21`; the image would contradict their manifest|

---

## Local testing

```bash
# JDK variant
docker buildx build --platform linux/amd64 -f images/jdk/Dockerfile -t codehunters-ci:dev .
docker run --rm codehunters-ci:dev /usr/local/bin/smoke-test.sh

# GraalVM variant
docker buildx build --platform linux/amd64 -f images/graalvm/Dockerfile -t codehunters-ci:dev-graalvm .
docker run --rm -e CI_VARIANT=graalvm codehunters-ci:dev-graalvm /usr/local/bin/smoke-test.sh

# KrakenD variant
docker buildx build --platform linux/amd64 -f images/krakend/Dockerfile -t codehunters-ci:dev-krakend .
docker run --rm -e CI_VARIANT=krakend codehunters-ci:dev-krakend /usr/local/bin/smoke-test.sh

# Node variant
docker buildx build --platform linux/amd64 -f images/node/Dockerfile -t codehunters-ci:dev-node .
docker run --rm -e CI_VARIANT=node codehunters-ci:dev-node /usr/local/bin/smoke-test.sh

# Interactive shell
docker run --rm -it codehunters-ci:dev
```

Multi-arch local build (requires buildx + QEMU):

```bash
docker buildx build --platform linux/amd64,linux/arm64 -f images/jdk/Dockerfile -t codehunters-ci:dev .
docker buildx build --platform linux/amd64,linux/arm64 -f images/graalvm/Dockerfile -t codehunters-ci:dev-graalvm .
docker buildx build --platform linux/amd64,linux/arm64 -f images/krakend/Dockerfile -t codehunters-ci:dev-krakend .
docker buildx build --platform linux/amd64,linux/arm64 -f images/node/Dockerfile -t codehunters-ci:dev-node .
```

Building for a foreign architecture on Apple Silicon: pass `TARGETARCH`
explicitly (`--build-arg TARGETARCH=arm64`). Without it the build takes the
`amd64` default, pulls the x86_64 AWS CLI and dies under Rosetta before the
smoke test runs.

`CI_VARIANT` is baked into each image as an env var and controls
variant-specific smoke assertions (e.g. `native-image --version` is asserted
only when `CI_VARIANT=graalvm`).

---

## Repository layout

```
images/
  jdk/Dockerfile          # Temurin 21 (Alpine/musl)
  graalvm/Dockerfile      # GraalVM CE for JDK 21 (Oracle Linux 9 / glibc)
  krakend/Dockerfile      # alpine:3.21 + multi-stage COPY of krakend + golang
  node/Dockerfile         # Node 20 (Alpine/musl) + npm + corepack + node-gyp deps
scripts/                  # Install + smoke scripts (dispatcher per pkg manager)
  install-base-packages.sh           # dispatcher
  install-base-packages-alpine.sh    # apk path
  install-base-packages-ol.sh        # microdnf + EPEL path
  install-docker-cli.sh              # dispatcher
  install-docker-cli-alpine.sh       # apk
  install-docker-cli-ol.sh           # docker-ce repo + microdnf
  install-aws-cli.sh                 # libc-aware (musl pin vs glibc latest)
  install-gradle.sh                  # libc-agnostic (tarball + sha256)
  install-native-image.sh            # GraalVM-only verifier
  install-krakend.sh                 # KrakenD-only verifier (binary COPYed in Dockerfile)
  install-go.sh                      # KrakenD-only Go toolchain + plugin-deps verifier
  cleanup.sh                         # dispatcher
  cleanup-alpine.sh / cleanup-ol.sh
  smoke-test.sh                      # CI_VARIANT-gated
```

The build context is the repo root — both Dockerfiles `COPY scripts/` into
`/usr/local/bin/` and invoke dispatchers at build time.

---

## Versioning policy

Semver. Cut a new release with:

```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

The `build-publish.yml` workflow picks up the tag and publishes **all three
variants** at the same semver: `:v1.0.0` + `:v1.0.0-graalvm` +
`:v1.0.0-krakend`, plus the matching rolling tags (`:v1.0`, `:v1`,
`:v1.0-graalvm`, `:v1-graalvm`, `:v1.0-krakend`, `:v1-krakend`) and
`:sha-<short>` / `:sha-<short>-graalvm` / `:sha-<short>-krakend`.

`:latest`, `:graalvm`, and `:krakend` are **not** updated on tag pushes —
only on `main` pushes.

### When to bump

| Change                                                  | Bump  |
|---------------------------------------------------------|-------|
| JDK major upgrade (21 → 25)                             | major |
| Gradle major upgrade (9.x → 10.x)                       | major |
| KrakenD major upgrade (2.x → 3.x)                       | major |
| Go major upgrade (forced by KrakenD runtime ABI bump)   | major |
| Removing a pre-installed tool from any variant          | major |
| Switching any variant's base image family               | major |
| Adding a pre-installed tool                             | minor |
| Gradle / AWS CLI / KrakenD / Go minor/patch upgrades    | minor |
| Internal script refactor, base image patch refresh      | patch |

---

## GHCR package visibility

After the first publish, mark the GHCR package **public** (one-time UI step at
`https://github.com/users/codehunters/packages/container/ci-base-images/settings`).

Otherwise every consumer workflow needs an explicit `docker/login-action` step.

---

## Security

Images run as `root` — required for `apk` / `microdnf`, and for `wg-quick`
inside containerised CI jobs. **Never** use as a runtime base for application
containers. Reports of vulnerabilities: andresmontoyat@gmail.com.
