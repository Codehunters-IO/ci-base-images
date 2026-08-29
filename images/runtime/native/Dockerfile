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
FROM debian:12-slim AS libs
RUN set -eux; \
    mkdir -p /staging; \
    cp -a /usr/lib/*-linux-gnu/libz.so.1* /staging/

FROM gcr.io/distroless/base-debian12:nonroot

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
