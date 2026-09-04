# Security Policy

## Reporting a Vulnerability

Email: andresmontoyat@gmail.com

Please include:
- Affected image tag(s)
- Reproduction steps
- Impact assessment

## Scope

Two families with opposite rules.

The **`ci/`** images are CI-only. They run as `root` to support `apk` and
`microdnf` inside GitHub Actions jobs, and carry a build toolchain, a Docker
CLI and an AWS CLI. They are **not** intended as a runtime base for application
containers.

The **`runtime/`** images are the opposite: non-root, no toolchain, no Docker
or AWS CLI, and meant to be inherited by application images.

Vulnerabilities affecting:
- Pre-installed tools in either family
- Install scripts
- The image build pipeline

are in scope. Using a **`ci/`** image as a runtime base is out of scope — that
usage is explicitly unsupported, and the `runtime/` images exist for it.

## Vulnerability scanning

Every image is scanned with Trivy at three points: on the pull request that
changes it, before it is pushed to the registry, and weekly against the tag
already published. The third one is the one that catches most of what matters —
an image is least likely to be vulnerable on the day it is built.

Results go to the repository's Security tab as code scanning alerts, so a
finding survives past the job log it was found in.

### What fails a build

| Family | Fails on |
|--------|----------|
| `runtime/` | `CRITICAL` or `HIGH` **with a fix available** |
| `ci/` | `CRITICAL` **with a fix available** |

The two tiers are the same policy applied to two different jobs. A `runtime/`
image faces traffic and outlives the request, so a fixable HIGH in it is a
defect. A `ci/` image is root with a full toolchain by design and exists for the
length of one job on an ephemeral runner; gating it on HIGH blocks every pull
request on `gcc` and `git` advisories nobody can act on, and a gate that is
always red is a gate everybody learns to click past.

Unfixed advisories are excluded from both tiers. An advisory with no upstream
patch cannot be resolved by anything done in this repository, so gating on it
does not make the images safer — it just makes the check permanently red.

### Keeping the base layers patched

The Alpine-based `runtime/` images run `apk upgrade` at build time, and the Node
one additionally installs `npm@11` over the 10.x that Node 20 bundles. Both are
there because upstream tags lag: when this was introduced the stock
`node:20.20.2-alpine` carried 24 fixable CRITICAL/HIGH advisories, twenty of
them inside npm's own `node_modules` where no consumer's lockfile can reach
them, and `eclipse-temurin:21-jre-alpine` carried five. Both are now zero.

The cost is reproducibility: two builds of the same Dockerfile on different days
can produce different bytes. For a base image that is the intended trade — it is
rebuilt and republished so that consumers inherit patches without editing
anything. Pin by digest downstream if you need a fixed input.

### Exceptions

Two mechanisms, for two different shapes of problem.

`.trivyignore.yaml` holds individual accepted findings. Each entry carries a
statement explaining why it cannot be fixed here and an `expired_at` date,
after which Trivy reports it again and the build fails. An exception that
outlives its reason is supposed to come back.

`.trivy/ignore-policy.rego` holds classes of finding that recur. Today it holds
one: kernel packages in a container image. `ci/graalvm` is built on Oracle
Linux and pulls `kernel-headers` in through `glibc-devel`, which `native-image`
requires. Those are C headers that get compiled against and never executed, and
a container does not boot its own kernel — it calls the host's, which the host
patches on its own schedule. A rule rather than a list because Oracle rates a
new kernel advisory CRITICAL often enough that a list would block `main` until
somebody appended to it, and a gate that needs regular unblocking is a gate
that gets removed. The other seven images carry no kernel packages, so it
matches nothing in them.

### Supply chain

Published images carry an SPDX SBOM and max-mode SLSA provenance as
attestations on the manifest:

```
docker buildx imagetools inspect ghcr.io/codehunters-io/ci-base-images:java-runtime \
  --format '{{ json .SBOM }}'
docker buildx imagetools inspect ghcr.io/codehunters-io/ci-base-images:java-runtime \
  --format '{{ json .Provenance }}'
```
