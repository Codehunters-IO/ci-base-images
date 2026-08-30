# syntax=docker/dockerfile:1.7
# ci-base-images (web runtime) — base for React/Vite static builds.
# Contents: nginx (Alpine), unprivileged, SPA fallback, security headers.
# Usage: FROM ghcr.io/codehunters-io/ci-base-images:X.Y.Z-web-runtime
#        COPY --from=build /src/dist /usr/share/nginx/html
FROM nginx:alpine

COPY images/runtime/web/conf/nginx.conf   /etc/nginx/nginx.conf
COPY images/runtime/web/conf/default.conf /etc/nginx/conf.d/default.conf

# The upstream image starts a root master process that drops to `nginx` for
# workers. Running as uid 101 outright means nginx never holds root at all, at
# the cost of having to own every path it writes to.
#
# `nginx -t` here runs as root and leaves a root-owned /tmp/nginx.pid behind. It
# gets baked into the layer, and uid 101 then cannot open it — the container
# fails at startup, not at build. Hence the rm.
RUN set -eux; \
    apk add --no-cache tzdata ca-certificates; \
    rm -f /docker-entrypoint.d/*envsubst*; \
    mkdir -p /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp \
             /tmp/uwsgi_temp /tmp/scgi_temp; \
    chown -R nginx:nginx /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp \
                         /tmp/uwsgi_temp /tmp/scgi_temp \
                         /usr/share/nginx/html /etc/nginx/conf.d; \
    nginx -t; \
    rm -f /tmp/nginx.pid

ENV LANG=C.UTF-8 \
    TZ=UTC

EXPOSE 8080
USER nginx

STOPSIGNAL SIGQUIT
ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]

LABEL org.opencontainers.image.title="ci-base-images (web runtime)" \
      org.opencontainers.image.description="Runtime base for React/Vite static builds (nginx, unprivileged, SPA fallback)" \
      org.opencontainers.image.source="https://github.com/Codehunters-IO/ci-base-images" \
      org.opencontainers.image.vendor="codehunters" \
      org.opencontainers.image.licenses="MIT" \
      io.codehunters.usage="runtime" \
      io.codehunters.variant="web-runtime" \
      io.codehunters.contents.libc="musl" \
      io.codehunters.contents.base="nginx:alpine" \
      io.codehunters.runs-as="nginx" \
      io.codehunters.listen-port="8080"
