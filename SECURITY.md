# Security Policy

## Reporting a Vulnerability

Email: andresmontoyat@gmail.com

Please include:
- Affected image tag(s)
- Reproduction steps
- Impact assessment

## Scope

This image is **CI-only**. It is not intended as a runtime base for
application containers and runs as `root` to support `apk`, `apt`, and
`wg-quick` invocations inside GitHub Actions jobs.

Vulnerabilities affecting:
- Pre-installed tools (JDK, Gradle, AWS CLI v2, Docker CLI, WireGuard tools)
- Install scripts
- The image build pipeline

are in scope. Vulnerabilities in downstream consumers using this image as a
runtime base are **out of scope** — that usage is explicitly unsupported.
