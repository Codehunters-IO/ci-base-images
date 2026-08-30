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
