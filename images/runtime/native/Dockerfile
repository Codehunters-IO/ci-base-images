# syntax=docker/dockerfile:1.7
# ci-base-images (native runtime) — base for GraalVM native-image binaries.
# Contents: distroless glibc userland + libz. No shell, no package manager.
# Usage: FROM ghcr.io/codehunters-io/ci-base-images:X.Y.Z-native-runtime
#        COPY --from=build /src/build/native/nativeCompile/app /app/app
#        ENTRYPOINT ["/app/app"]

# native-image links libz.so.1 dynamically, and distroless/base does not carry
# it — 282 shared objects, none of them zlib. Without this the binary dies at
# exec with "error while loading shared libraries: libz.so.1". Staged from the
# same Debian 12 the distroless image is built from, so the glibc matches.
FROM debian:12-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251 AS libs
RUN set -eux; \
    mkdir -p /staging; \
    cp -a /usr/lib/*-linux-gnu/libz.so.1* /staging/

FROM gcr.io/distroless/base-debian12:nonroot@sha256:7f0c72cd138b442ae0deeb69c08b1acf5525439ba251a49ad93c320a061567e5

COPY --from=libs /staging/ /usr/lib/

ENV LANG=C.UTF-8 \
    TZ=UTC

WORKDIR /app
# uid 65532, from the upstream image. There is no shell and no adduser here, so
# the user has to be one distroless already ships.
USER nonroot

LABEL org.opencontainers.image.title="ci-base-images (native runtime)" \
      org.opencontainers.image.description="Runtime base for GraalVM native-image binaries (distroless, no shell, non-root)" \
      org.opencontainers.image.source="https://github.com/Codehunters-IO/ci-base-images" \
      org.opencontainers.image.vendor="codehunters" \
      org.opencontainers.image.licenses="MIT" \
      io.codehunters.usage="runtime" \
      io.codehunters.variant="native-runtime" \
      io.codehunters.contents.libc="glibc" \
      io.codehunters.contents.shell="none" \
      io.codehunters.contents.base="gcr.io/distroless/base-debian12:nonroot" \
      io.codehunters.runs-as="nonroot"
