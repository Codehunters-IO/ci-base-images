# ci-base-images

Pre-baked CI base images for `codehunters-ms-*` Java microservice and
`codehunters/tickets` contract pipelines. Replaces per-run installs
(`setup-java`, `setup-gradle`, `setup-node`, AWS CLI download) with a single
`container:` directive in GitHub Actions.

Eleven variants are published to `ghcr.io/codehunters-io/ci-base-images` —
six for CI, five for runtime:

| Variant         | Tag suffix    | Base image                              | libc  | Approx size | Use case                                  |
|-----------------|---------------|-----------------------------------------|-------|-------------|-------------------------------------------|
| **JDK**         | _(none)_      | `eclipse-temurin:21-jdk-alpine`         | musl  | ~450 MB     | `codehunters-ms-*` build/test/deploy (default)  |
| **JDK 25**      | `-jdk25`      | `eclipse-temurin:25-jdk-alpine`         | musl  | ~450 MB     | the same, for services on the JDK 25 LTS  |
| **GraalVM**     | `-graalvm`    | `ghcr.io/graalvm/native-image-community:21` | glibc | ~1.1 GB     | `nativeCompile` / `native-image` jobs     |
| **GraalVM 25**  | `-graalvm25`  | `ghcr.io/graalvm/native-image-community:25` | glibc | ~1.1 GB     | the same, for services on the JDK 25 LTS  |
| **KrakenD**     | `-krakend`    | `alpine:3.21` + `krakend` + `golang`    | musl  | ~700 MB     | `codehunters-gw-krakend` gateway pipelines      |
| **Node**        | `-node`       | `node:20.20.2-alpine`                   | musl  | ~210 MB     | Hardhat/Solidity + TypeScript SDK pipelines |

> **Java 21 is still the default.** The unsuffixed tags — `:latest`, `:vX.Y.Z` —
> remain JDK 21, and nothing pinning them changes. Java 25 is opt-in per
> repository by moving to the `-jdk25` / `-java25-runtime` / `-graalvm25`
> suffix. Both majors are built from the same commit and share the same semver,
> so a consumer picks the major without picking a different release.

> **Two families, opposite rules.** The `ci/` images run as `root` and carry a
> build toolchain — they exist to run pipeline steps and must **never** be a
> runtime base. The `runtime/` images run non-root, carry no toolchain, no
> Docker CLI and no AWS CLI, and are the ones your applications inherit from.

Architectures for every variant: `linux/amd64`, `linux/arm64` (multi-arch manifest).

---

## Two families

| | `ci/` | `runtime/` |
|---|---|---|
| Purpose | run pipeline steps | be the base of your app image |
| User | `root` | non-root, fixed uid |
| Java | JDK 21 or 25 + Gradle | JRE 21 or 25, or distroless for native binaries |
| Node | + `build-base`, `python3` | runtime only, no compiler |
| Also carries | Docker CLI, AWS CLI, git, gnupg | none of it |
| Size | 210 MB – 1.1 GB | 60 – 190 MB |

The second row of "also carries" is the one that matters. A Docker client and
an AWS CLI inside a container that serves traffic are tools an attacker
inherits along with the application, together with whatever credentials the
environment holds. Acceptable in CI, where the job is already trusted with
them. Not acceptable in production.

### Runtime variants

| Variant | Tag suffix | Base | Runs as | For |
|---|---|---|---|---|
| Java | `-java-runtime` | `eclipse-temurin:21-jre-alpine` | uid 10001 | Spring Boot jars |
| Java 25 | `-java25-runtime` | `eclipse-temurin:25-jre-alpine` | uid 10001 | Spring Boot jars on the JDK 25 LTS |
| Node | `-node-runtime` | `node:20.20.2-alpine` | uid 1000 (`node`) | Node/NestJS services |
| Web | `-web-runtime` | `nginx:alpine` | uid 101 (`nginx`), port 8080 | React/Vite static builds |
| Native | `-native-runtime` | `gcr.io/distroless/base-debian12` | uid 65532 | GraalVM `nativeCompile` binaries |

Multi-stage is the intended shape — build in the `ci` image, ship in the
`runtime` one:

```dockerfile
FROM ghcr.io/codehunters-io/ci-base-images:1.2.0 AS build
WORKDIR /src
COPY . .
RUN ./gradlew bootJar --no-daemon

FROM ghcr.io/codehunters-io/ci-base-images:1.2.0-java-runtime
COPY --from=build /src/build/libs/*.jar /app/app.jar
CMD ["java", "-jar", "/app/app.jar"]
```

Worked examples for each runtime — Java 21 and 25, GraalVM native, Node, static
web — are under [Building an application image](#building-an-application-image).

---

## What's inside

Common to **all** variants:

| Tool             | Version             | Source                              |
|------------------|---------------------|-------------------------------------|
| AWS CLI          | v2 (musl: apk `aws-cli`; glibc: 2.36.32 pinned) | Alpine community repo (apk signatures) / awscli.amazonaws.com (PGP) |
| Docker CLI       | distro repo         | apk (Alpine) / docker-ce (OL9)      |
| Docker Buildx    | distro repo         | apk / docker-buildx-plugin          |
| GNU userland     | coreutils, gawk, sed, grep | apk / microdnf               |
| Misc             | bash, jq, bc, curl, wget, git, openssh, gnupg, tzdata | apk / microdnf |

Variant-specific tooling:

| Tool / runtime    | JDK | JDK 25 | GraalVM | GraalVM 25 | KrakenD | Node | Source                           |
|-------------------|:---:|:------:|:-------:|:----------:|:-------:|:----:|----------------------------------|
| Temurin JDK 21    | ✅  | ❌     | ❌      | ❌         | ❌      | ❌   | `eclipse-temurin:21-jdk-alpine`  |
| Temurin JDK 25    | ❌  | ✅     | ❌      | ❌         | ❌      | ❌   | `eclipse-temurin:25-jdk-alpine`  |
| GraalVM CE JDK 21 | ❌  | ❌     | ✅      | ❌         | ❌      | ❌   | `ghcr.io/graalvm/native-image-community:21` |
| GraalVM CE JDK 25 | ❌  | ❌     | ❌      | ✅         | ❌      | ❌   | `ghcr.io/graalvm/native-image-community:25` |
| `native-image`    | ❌  | ❌     | ✅      | ✅         | ❌      | ❌   | preinstalled in GraalVM 21+      |
| Gradle CLI 9.7.1  | ✅  | ✅     | ✅      | ✅         | ❌      | ❌   | services.gradle.org (SHA-256 pinned) |
| KrakenD CLI       | ❌  | ❌     | ❌      | ❌         | ✅      | ❌   | `krakend:${KRAKEND_VERSION}` (multi-stage COPY) |
| Go toolchain      | ❌  | ❌     | ❌      | ❌         | ✅      | ❌   | `golang:${GO_VERSION}-alpine` (multi-stage COPY) |
| `build-base`      | ❌  | ❌     | ❌      | ❌         | ✅      | ✅   | apk (Go plugins on KrakenD; node-gyp on Node) |
| `binutils-gold` (for `go build -buildmode=plugin`) | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | apk |
| `make`            | ❌  | ❌     | ❌      | ❌         | ✅      | ✅   | apk                              |
| Node.js 20 + npm  | ❌  | ❌     | ❌      | ❌         | ❌      | ✅   | `node:${NODE_VERSION}-alpine`    |
| corepack (pnpm/yarn on demand) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | bundled with Node 20, enabled at build |
| `python3` (node-gyp) | ❌ | ❌  | ❌     | ❌         | ❌      | ✅   | apk                              |

Every Java image also carries `CI_JAVA_MAJOR` — the major it claims — and its
smoke test asserts the running JVM reports that same major. Two majors are
published from near-identical directories, and a `FROM` edited in one with the
label edited in the other leaves both files internally consistent, so
`check-pins.sh` cannot see it. The JVM is asked instead.

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

JDK 25 variant (`-jdk25` suffix) — identical tag shape, `jdk25` in place of
`latest` as the rolling tag:

| Tag                     | Trigger                                    | Use case                          |
|-------------------------|--------------------------------------------|-----------------------------------|
| `vX.Y.Z-jdk25`          | Git tag `v*`                                | Production pipelines on JDK 25 (PIN) |
| `vX.Y-jdk25`, `vX-jdk25`| Git tag `v*`                                | Tolerant rolling updates          |
| `jdk25`                 | Push to `main`                              | Development pipelines on JDK 25   |
| `sha-<short>-jdk25`     | Every build                                 | Reproducible debugging            |
| `main-jdk25`            | Push to `main`                              | Bleeding edge                     |

The `-graalvm25` and `-java25-runtime` variants follow the same shape, with
`graalvm25` and `java25-runtime` as their rolling tags.

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

**Production rule:** pin a semver tag (e.g. `:1.2.0`, `:1.2.0-graalvm`,
`:1.2.0-java-runtime`). Never a rolling tag — `:latest`, `:graalvm`,
`:node`, `:java-runtime` — in release or prod paths. All eleven variants are
built from the same commit and share the same semver: pick the variant by
suffix, the version by number. That includes the Java major — `:1.2.0` and
`:1.2.0-jdk25` are the same release, built from the same commit, differing
only in the JDK they carry.

---

## Usage in a consumer workflow

### JDK variant (default — build / test / deploy)

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/codehunters-io/ci-base-images:1.2.0
    steps:
      - uses: actions/checkout@v5

      - name: Build with Gradle
        env:
          GH_PACKAGES_USERNAME: ${{ secrets.GH_PACKAGES_USERNAME }}
          GH_PACKAGES_TOKEN: ${{ secrets.GH_PACKAGES_TOKEN }}
        run: ./gradlew clean build -x test --no-daemon --build-cache --parallel
```

`actions/setup-java@v5` and `gradle/actions/setup-gradle@v4` are dropped — the
image already has Temurin 21 and Gradle 9.7.1 on `$PATH`.

### Moving a repository to Java 25

Three tags change, and nothing else. The version stays the same — both majors
are built from the same commit — so this is one suffix per stage, not a version
bump:

| Stage        | From                  | To                            |
|--------------|-----------------------|-------------------------------|
| build / test | `:1.2.0`              | `:1.2.0-jdk25`                |
| `nativeCompile` | `:1.2.0-graalvm`   | `:1.2.0-graalvm25`            |
| app image    | `:1.2.0-java-runtime` | `:1.2.0-java25-runtime`       |

```yaml
    container:
      image: ghcr.io/codehunters-io/ci-base-images:1.2.0-jdk25
```

Move the build stage and the runtime stage together: a jar compiled with
`--release 25` will not start on the JRE 21 runtime image, and the failure
surfaces at container start rather than at build. The JDK 21 variants are not
deprecated and are not going anywhere — the unsuffixed tags stay on 21.

### Building an application image

The CI examples above cover the pipeline side. These are the other half — the
`Dockerfile` in a consumer repository. Build in the `ci` image, ship in the
`runtime` one; the CI image must never be the base of something that serves
traffic.

**Spring Boot on Java 21** — the default, unsuffixed tag:

```dockerfile
FROM ghcr.io/codehunters-io/ci-base-images:1.2.0 AS build
WORKDIR /src
COPY . .
RUN ./gradlew bootJar --no-daemon --build-cache

FROM ghcr.io/codehunters-io/ci-base-images:1.2.0-java-runtime
COPY --from=build /src/build/libs/*.jar /app/app.jar
EXPOSE 8080
CMD ["java", "-jar", "/app/app.jar"]
```

`JAVA_TOOL_OPTIONS` is already set to `-XX:MaxRAMPercentage=75.0
-XX:+ExitOnOutOfMemoryError`, so the heap follows the container limit instead
of the host's memory, and an OOM kills the process rather than leaving a JVM
thrashing behind a passing health check. Override it if you must; do not unset
it. `tini` is the entrypoint, so anything the app forks gets reaped.

**Spring Boot on Java 25** — both stages move together:

```dockerfile
FROM ghcr.io/codehunters-io/ci-base-images:1.2.0-jdk25 AS build
WORKDIR /src
COPY . .
RUN ./gradlew bootJar --no-daemon --build-cache

FROM ghcr.io/codehunters-io/ci-base-images:1.2.0-java25-runtime
COPY --from=build /src/build/libs/*.jar /app/app.jar
EXPOSE 8080
CMD ["java", "-jar", "/app/app.jar"]
```

Moving only the build stage is the mistake worth naming: a jar compiled with
`--release 25` on the JRE 21 runtime image fails at container start with
`UnsupportedClassVersionError`, not at build, so it passes CI and dies on
deploy.

**GraalVM native binary** — build on GraalVM, ship on distroless:

```dockerfile
FROM ghcr.io/codehunters-io/ci-base-images:1.2.0-graalvm AS build
WORKDIR /src
COPY . .
RUN ./gradlew nativeCompile --no-daemon --build-cache

FROM ghcr.io/codehunters-io/ci-base-images:1.2.0-native-runtime
COPY --from=build /src/build/native/nativeCompile/app /app/app
EXPOSE 8080
ENTRYPOINT ["/app/app"]
```

Use `-graalvm25` for the build stage on Java 25; the native runtime image is
unchanged either way, because a compiled binary carries no JVM. That image
ships `libz.so.1`, which `distroless/base` does not and every `native-image`
binary links dynamically — without it the binary dies at exec. It has no
shell, so `RUN`, `CMD ["sh", ...]` and `docker exec ... sh` are all
unavailable in the final stage: everything must be done in the build stage.

**Node service:**

```dockerfile
FROM ghcr.io/codehunters-io/ci-base-images:1.2.0-node AS build
WORKDIR /src
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build && npm prune --omit=dev

FROM ghcr.io/codehunters-io/ci-base-images:1.2.0-node-runtime
COPY --from=build /src/node_modules /app/node_modules
COPY --from=build /src/dist /app/dist
EXPOSE 3000
CMD ["node", "/app/dist/main.js"]
```

The runtime image carries no compiler, no `make` and no `python3`. A dependency
with a native addon and no musl prebuild has to be built in the `ci` stage —
which is why `node_modules` is copied across rather than installed in the final
stage.

**React/Vite static build:**

```dockerfile
FROM ghcr.io/codehunters-io/ci-base-images:1.2.0-node AS build
WORKDIR /src
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM ghcr.io/codehunters-io/ci-base-images:1.2.0-web-runtime
COPY --from=build /src/dist /usr/share/nginx/html
```

Port **8080**, not 80 — a non-root worker cannot bind a privileged port, so
map it accordingly (`-p 80:8080`, or a `targetPort: 8080` in the Service). SPA
fallback, immutable caching for hashed assets, `no-cache` for `index.html` and
a `/healthz` endpoint are already configured; add none of it yourself.

**Running one locally**, to check the image before the pipeline does:

```bash
docker build -t my-service:dev .
docker run --rm -p 8080:8080 my-service:dev

# what major does this actually carry?
docker run --rm --entrypoint sh my-service:dev -c 'java -version; echo $CI_JAVA_MAJOR'
```

### GraalVM variant (native-image)

```yaml
jobs:
  native-build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/codehunters-io/ci-base-images:1.2.0-graalvm
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
      image: ghcr.io/codehunters-io/ci-base-images:1.2.0-krakend
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
      image: ghcr.io/codehunters-io/ci-base-images:1.2.0-node
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

---

## End-to-end example: deploy a `codehunters-ms-*` service

Canonical pattern used by `codehunters-ms-payment`, `codehunters-ms-auth`,
`codehunters-ms-raffles`, `codehunters-ms-file-share`. The per-service repo delegates to
the shared reusable workflow in `codehunters/ci-templates`, which runs every stage
(build, test, ECR publish, EC2 deploy) inside this image.

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
  image: ghcr.io/codehunters-io/ci-base-images:1.2.0
```

Bumping that single pin in `ci-templates` rolls every `codehunters-ms-*` pipeline to
the new image. No `setup-java`, no `setup-gradle`, no AWS CLI download — every
tool is already on `$PATH`.

The VPN deploy target is not served from here. `shared-deploy-ec2-vpn.yml`
installs `wireguard-tools` on the runner itself and brings the tunnel up
outside any job container, so the image carries no WireGuard and needs no
`NET_ADMIN`.

| Pipeline stage          | Tool used         | From this image             |
|-------------------------|-------------------|-----------------------------|
| Compile + test          | `java`, `gradle`  | yes                         |
| OWASP dep-check         | `gradle` plugin   | yes                         |
| Build OCI image         | `docker buildx`   | yes                         |
| ECR login + push        | `aws`, `docker`   | yes                         |
| Open release PR         | `gh`/`git`        | yes (`git` baked in)        |
| Drive remote deploy     | `ssh`, `bash`     | yes                         |
| Patch compose file      | `sed`, `awk`      | yes (GNU userland)          |

Typical saving: **~90 s** per job vs. the legacy `setup-java + setup-gradle +
apt-get + curl awscli` sequence.

### Native-image variant

Services that run `./gradlew nativeCompile` pin the `-graalvm` suffix tag in
their `ci-templates` invocation. Only the build job needs the larger GraalVM
image; deploy stays on the JDK variant (`ssh`, `aws`, `docker` are identical
across variants).

### KrakenD gateway (`codehunters-gw-krakend`)

The gateway repo uses a separate reusable workflow
(`krakend-main-pipeline.yml`) that runs every stage inside the KrakenD
variant of this image: `krakend check` (Flexible Config validation),
`go build -buildmode=plugin` for the custom plugins (`jwt-headers`,
`ip-resolver`, `trace-context`), `docker buildx` for the gateway image, and
SSH for the EC2 deploy.

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
  image: ghcr.io/codehunters-io/ci-base-images:1.2.0-krakend
```

One pin bumps every KrakenD stage at once. The KrakenD CLI version and Go
toolchain are baked into the image (`KRAKEND_VERSION` + `GO_VERSION` build
args); upgrading them requires a new image release, which avoids drift
between gateway runtime (`krakend:2.13.11`) and CI plugin builds.

---

## Base image rationale

### JDK variant — `eclipse-temurin:21-jdk-alpine`

Chosen for compactness over `:21-jdk-jammy`. Trade-off: musl libc, which AWS
does not build for: the official CLI bundle is a glibc PyInstaller binary. It
used to run here under `gcompat`, pinned to 2.17.65 to dodge a missing symbol,
until newer Alpine releases broke it outright. The CLI now comes from the
Alpine community repository — a native musl build, verified by apk's own
package signatures, and no shim.

The only AWS command exercised in CI is `aws ecr get-login-password`. A smoke
test catches regressions before publish.

| Candidate                            | Reason rejected                                   |
|--------------------------------------|---------------------------------------------------|
| `eclipse-temurin:21-jdk-jammy`       | ~50 MB larger than alpine; no functional gain     |
| `amazoncorretto:21-alpine`           | Vendor-inconsistent (workflows specify `temurin`) |
| `alpine:3.20` + manual JDK install   | Saves only ~5 MB; adds lifecycle burden           |
| `debian:bookworm-slim` + manual JDK  | Larger than alpine after tooling added            |
| `distroless`                         | No shell — breaks CI shell scripts                |

### GraalVM variant — `ghcr.io/graalvm/native-image-community:21`

GraalVM Community Edition does not publish an Alpine/musl image. Oracle Linux
9 (glibc) is the official base. `native-image` is not part of the JDK: the
`gu` component installer was removed in GraalVM 23.x, and what replaced it is
a second image that ships the tool rather than a way to add it. `native-image`
and `javac` live in `$JAVA_HOME/bin`, which is why this variant puts that
directory on `PATH`.

On glibc the official AWS bundle runs natively, so this is the one variant that
installs it. It is pinned (`AWS_CLI_VERSION`) rather than tracking `latest`, so
a rebuild reproduces the same artifact, and its signature is checked — see
[AWS CLI integrity](#aws-cli-integrity).

| Candidate                                       | Reason rejected                                   |
|-------------------------------------------------|---------------------------------------------------|
| `container-registry.oracle.com/graalvm/jdk:21`  | Commercial Oracle GraalVM; licence restrictions   |
| `ghcr.io/graalvm/jdk-community:21`              | JDK only — no `native-image` in `$JAVA_HOME/bin`  |
| Custom Alpine + GraalVM tarball                 | No official musl build; binary-compat risk        |

### Java 25 variants — `eclipse-temurin:25-*-alpine`, `native-image-community:25`

Same reasoning as their 21 counterparts above, same libc, same AWS CLI path —
the base image family does not change, only the JDK major. What is worth
stating is why they are separate images rather than a bumped `FROM`.

The JDK major is this repository's contract. It is named in the tag suffix, in
`io.codehunters.contents.java`, in this README and in every consumer's
`container:` line. Moving an existing variant to a new major makes all of those
lie at once and breaks anyone pinned to the tag; publishing a new variant
alongside breaks nobody and lets each repository move when its own build is
ready. So 21 keeps the unsuffixed tags and 25 arrives beside it.

That choice costs duplication — two near-identical Dockerfiles per family — and
`check-pins.sh` is what keeps the copies from drifting, backed by the
`CI_JAVA_MAJOR` assertion in the smoke tests for the one case the static check
cannot see. The alternative, a single Dockerfile with `FROM ${JAVA_IMAGE}`,
would hide every base from Dependabot and cost digest pinning, which is a worse
trade.

| Candidate                                  | Reason rejected                                        |
|--------------------------------------------|--------------------------------------------------------|
| Bump `images/ci/jdk` from 21 to 25          | Breaks every consumer pinned to `:latest` or `:vX.Y.Z`  |
| One Dockerfile, `ARG JAVA_VERSION`          | Dependabot cannot see or update a non-literal `FROM`    |
| Temurin 26                                  | Not an LTS; the consumers track LTS majors              |
| Java 27                                     | Does not exist upstream — no Temurin or GraalVM image   |

### KrakenD variant — `alpine:3.24` + multi-stage COPY

Alpine 3.24 is the base; the `krakend` binary is COPYed from the official
`krakend:${KRAKEND_VERSION}` image and the Go toolchain from
`golang:${GO_VERSION}-alpine`. Three reasons for this shape:

1. **ABI compatibility** for `go build -buildmode=plugin`: the runtime image
   (`krakend:2.13.11`) is built against a specific Go version — go1.26.8,
   read off the binary with `go version -m`, not guessed. Plugin `.so` files
   must be built with the **exact same** Go version or they fail to load. apk's
   Go is typically behind — multi-stage COPY pins the version deterministically,
   and `GO_VERSION` moves only when `KRAKEND_VERSION` does.
2. **Single CI container** for the full gateway pipeline: KrakenD CLI
   (`krakend check`), Go plugin compile (`-buildmode=plugin` needs
   `binutils-gold`), `docker buildx` (gateway image build), `aws ecr` push,
   and `ssh` for EC2 deploy — no per-job tool install.
3. **No JDK/Gradle** in this variant — gateway repos don't need them; saves
   ~250 MB versus stuffing them into the JDK base.

| Candidate                                          | Reason rejected                                          |
|----------------------------------------------------|----------------------------------------------------------|
| `krakend:2.13.11` directly as CI base              | Lacks Go, docker, aws, ssh — defeats the purpose         |
| `golang:1.26.8-alpine` directly as CI base         | Lacks krakend CLI, aws v2, docker                        |
| Extending the JDK variant with Go + KrakenD        | ~1.2 GB image; pulls Temurin for no gateway purpose      |
| `debian:bookworm-slim` + apt Go                    | apt Go = 1.21; ABI mismatch with `krakend/builder` (1.26)|

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

Build any variant from the repo root — the build context is the root, not the
image directory, because every Dockerfile `COPY scripts/`:

```bash
# CI images (the smoke test is baked in)
docker build -f images/ci/jdk/Dockerfile       -t cbi:dev-jdk       .
docker build -f images/ci/jdk25/Dockerfile     -t cbi:dev-jdk25     .
docker build -f images/ci/graalvm/Dockerfile   -t cbi:dev-graalvm   .
docker build -f images/ci/graalvm25/Dockerfile -t cbi:dev-graalvm25 .
docker build -f images/ci/krakend/Dockerfile   -t cbi:dev-krakend   .
docker build -f images/ci/node/Dockerfile      -t cbi:dev-node      .

# runtime images (they carry no test code — the script is mounted in)
docker build -f images/runtime/java/Dockerfile   -t cbi:dev-java-runtime   .
docker build -f images/runtime/java25/Dockerfile -t cbi:dev-java25-runtime .
docker build -f images/runtime/node/Dockerfile   -t cbi:dev-node-runtime   .
docker build -f images/runtime/web/Dockerfile    -t cbi:dev-web-runtime    .
docker build -f images/runtime/native/Dockerfile -t cbi:dev-native-runtime .
```

A CI image runs its smoke test during the build, so a green build is already a
green smoke test. To re-run one against an image you have, or to test a runtime
image at all, go through the dispatcher — each family is tested differently and
the difference is not incidental:

```bash
# ci       — the script is baked into the image
IMAGE=cbi:dev-jdk25 KIND=ci VARIANT=jdk ./scripts/run-smoke.sh

# runtime  — the script is mounted, because runtime images carry no test code
IMAGE=cbi:dev-java25-runtime KIND=runtime VARIANT=java ./scripts/run-smoke.sh

# web      — same, but nginx is the entrypoint and has to be overridden
IMAGE=cbi:dev-web-runtime KIND=web VARIANT=web ./scripts/run-smoke.sh

# native   — nothing runs inside: no shell. Asserted from the host instead.
IMAGE=cbi:dev-native-runtime KIND=native ./scripts/run-smoke.sh
```

`VARIANT` picks the assertions, not the Java major. The major each image claims
travels inside it as `CI_JAVA_MAJOR`, and the smoke test fails if the running
JVM disagrees — so `VARIANT=jdk` is correct for both `jdk` and `jdk25`, and the
check cannot be handed the answer it is meant to verify.

Before opening a PR, run the same pin check CI runs:

```bash
./scripts/check-pins.sh
```

It asserts every `FROM` carries a digest, that each `io.codehunters.contents.base`
label agrees with its own final `FROM`, and that a version `ARG` duplicated into
a literal `FROM` still matches it.

Multi-arch local build (needs buildx + QEMU, or a native arm64 host):

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -f images/ci/jdk25/Dockerfile -t cbi:dev-jdk25 .
```

`TARGETARCH` needs no `--build-arg`: it is declared without a default, so
BuildKit fills it with the platform being built. Giving it one would shadow
that value, and a foreign-architecture build would fetch x86_64 artefacts.

---

## Repository layout

```
images/
  ci/                       # run pipeline steps. root, full toolchain.
    jdk/Dockerfile          #   Temurin 21 (Alpine/musl)
    jdk25/Dockerfile        #   Temurin 25 (Alpine/musl)
    graalvm/Dockerfile      #   GraalVM CE for JDK 21 (Oracle Linux 9 / glibc)
    graalvm25/Dockerfile    #   GraalVM CE for JDK 25 (Oracle Linux 9 / glibc)
    krakend/Dockerfile      #   alpine + multi-stage COPY of krakend + golang
    node/Dockerfile         #   Node 20 (Alpine/musl) + npm + corepack + node-gyp deps
  runtime/                  # be the base of your app image. non-root, no toolchain.
    java/Dockerfile         #   Temurin JRE 21, tini, uid 10001
    java25/Dockerfile       #   Temurin JRE 25, tini, uid 10001
    node/Dockerfile         #   Node 20, uid 1000
    web/Dockerfile          #   nginx unprivileged on 8080, SPA fallback
    web/conf/               #   nginx.conf + default.conf
    native/Dockerfile       #   distroless + libz, uid 65532, no shell
.github/workflows/          # thin callers only — the work lives in ci-templates
  pr-validation.yml         #   shared-validate-image-pr      (lint, gate, build, scan)
  build-publish.yml         #   shared-build-publish-image    (publish multi-arch + SBOM)
  security-scan.yml         #   shared-scan-published-images  (weekly rescan of the tags)
  cleanup-packages.yml      #   shared-cleanup-packages       (prune untagged versions)
scripts/                    # install + smoke scripts, dispatched per package manager
  install-base-packages.sh           # dispatcher
  install-base-packages-alpine.sh    #   apk path
  install-base-packages-ol.sh        #   microdnf + EPEL path
  install-docker-cli.sh              # dispatcher
  install-docker-cli-alpine.sh       #   apk
  install-docker-cli-ol.sh           #   docker-ce repo + microdnf
  install-aws-cli.sh                 # libc-aware (musl apk vs glibc bundle + PGP)
  install-gradle.sh                  # libc-agnostic (tarball + sha256)
  install-native-image.sh            # GraalVM-only verifier
  install-krakend.sh                 # KrakenD-only verifier (binary COPYed in Dockerfile)
  install-go.sh                      # KrakenD-only Go toolchain + plugin-deps verifier
  install-node-toolchain.sh          # Node-only verifier, enables corepack
  cleanup.sh                         # dispatcher
  cleanup-alpine.sh / cleanup-ol.sh
  run-smoke.sh                       # host-side dispatcher: ci / runtime / web / native
  smoke-test.sh                      # CI images, baked in, CI_VARIANT-gated
  smoke-test-runtime.sh              # runtime images, mounted in
  smoke-test-native.sh               # distroless, asserted from the host
  check-pins.sh                      # digest + label + ARG consistency gate
```

A directory per Java major, rather than one Dockerfile with an `ARG` over the
`FROM`: the `FROM`s are literal so Dependabot can see and update the digests,
and `FROM ${JAVA_IMAGE}` would hide every major from it.

The build context is the repo root — both Dockerfiles `COPY scripts/` into
`/usr/local/bin/` and invoke dispatchers at build time.

---

## How this repository's own CI works

Every workflow here is a caller. The four files in `.github/workflows/` declare
triggers, permissions and the image list; all of the work lives in reusable
workflows in [`Codehunters-IO/ci-templates`](https://github.com/Codehunters-IO/ci-templates).

| File | Reusable workflow | Does |
|------|-------------------|------|
| `pr-validation.yml` | `shared-validate-image-pr` | hadolint, ShellCheck, `check-pins.sh`, then build + smoke + CVE gate per image per architecture |
| `build-publish.yml` | `shared-build-publish-image` | publish multi-arch manifests with SBOM and provenance |
| `security-scan.yml` | `shared-scan-published-images` | weekly rescan of the tags consumers pull |
| `cleanup-packages.yml` | `shared-cleanup-packages` | prune untagged GHCR versions |

The image list appears in three of them rather than once, because a pull
request, a publish and a rescan need different fields — a Dockerfile path, a tag
suffix, a rolling tag. Adding a variant means editing all three, and the number
of entries is the first thing to check when one of them behaves oddly.

Each pins ci-templates by **commit SHA**, not `@v1`. A reusable workflow
resolves at call time, so a floating alias means any release there changes what
runs here with no commit in this repository. Bumping the pin is a reviewable
change; Dependabot proposes it.

**Two things stay local on purpose.** `scripts/` is the repository's own
knowledge — what a smoke test asserts for each variant, which pins have to
agree — and `check-pins.sh` reaches ci-templates as `gate_command`, a string
the shared workflow runs without knowing what it does. Anything more specific
than that would mean an input per consuming repository.

---

## Versioning policy

Semver. Cut a new release with:

```bash
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

The git tag carries the `v`; the published image tags do not. `docker/metadata-action`
strips it, so `v1.2.0` becomes `:1.2.0`.

The `build-publish.yml` workflow picks up the tag and publishes **all eleven
variants** at the same semver — `:1.2.0`, `:1.2.0-jdk25`, `:1.2.0-graalvm`,
`:1.2.0-graalvm25`, `:1.2.0-krakend`, `:1.2.0-node`, `:1.2.0-java-runtime`,
`:1.2.0-java25-runtime`, `:1.2.0-node-runtime`, `:1.2.0-web-runtime`,
`:1.2.0-native-runtime` — plus the matching `:1.1` and `:1` tags for each, and
`:sha-<short>` per variant.

Rolling tags are **not** updated on tag pushes —
only on `main` pushes.

### When to bump

| Change                                                  | Bump  |
|---------------------------------------------------------|-------|
| Moving an existing variant to a new JDK major           | major |
| Gradle major upgrade (9.x → 10.x)                       | major |
| KrakenD major upgrade (2.x → 3.x)                       | major |
| Go major upgrade (forced by KrakenD runtime ABI bump)   | major |
| Removing a pre-installed tool from any variant          | major |
| Switching any variant's base image family               | major |
| Adding a JDK major as a NEW variant, existing tags unchanged | minor |
| Adding a pre-installed tool                             | minor |
| Gradle / AWS CLI / KrakenD / Go minor/patch upgrades    | minor |
| Internal script refactor, base image patch refresh      | patch |

---

## GHCR package visibility

After the first publish, mark the GHCR package **public** (one-time UI step at
`https://github.com/orgs/Codehunters-IO/packages/container/ci-base-images/settings`).

Otherwise every consumer workflow needs an explicit `docker/login-action` step.

---

## Security

The `ci/` images run as `root` — required for `apk` / `microdnf` inside
containerised CI jobs — and must **never** be a runtime base for application
containers. The `runtime/` images are the supported base for that: non-root,
no build toolchain, no Docker or AWS CLI. Reports of vulnerabilities:
andresmontoyat@gmail.com.

### AWS CLI integrity

The CLI is inert without credentials, so what matters is that the binary is the
one AWS published.

On musl it comes from the Alpine community repository, and apk verifies the
package signature itself. On glibc it is the official bundle from
`awscli.amazonaws.com`, and `install-aws-cli.sh` checks its detached PGP
signature (`AWS_CLI_VERIFY_GPG=1`, the default).

Two details make that check real rather than decorative:

- **The key is vendored** at `scripts/aws-cli-pgp.asc`. AWS retired
  `https://awscli.amazonaws.com/aws-cli-pgp.txt` — it 404s — and fetching the
  key from the host that serves the artifact would let one compromised host
  supply both halves of the check.
- **The signer's fingerprint is pinned.** The script requires a `VALIDSIG` line
  for `FB5DB77FD5C118B80511ADA8A6310ACC4672475C` rather than trusting gpg's exit
  status, which is `0` for a good signature by *any* key in the keyring. It is
  also `0` for an expired one, and AWS has been signing with an expired key
  since 2026-07-07 — so `EXPKEYSIG` is expected here and `VALIDSIG` is what
  actually pins the signer.

Bumping `AWS_CLI_VERSION` is deliberate. `latest` would make each rebuild fetch
a different artifact, which is why the GraalVM variant pins it.

What this does **not** cover: the credentials themselves. A CI image that holds
long-lived IAM keys is a larger exposure than the CLI ever is — prefer GitHub
OIDC over static `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets, and an
EC2 instance profile over shipping keys to a deploy target.
