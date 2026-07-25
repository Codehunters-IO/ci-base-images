#!/bin/sh
# Install Docker CLI + buildx on Alpine (no daemon, no compose).
set -eu

apk add --no-cache \
    docker-cli \
    docker-cli-buildx

docker --version
docker buildx version
echo "Docker CLI + buildx (Alpine) installed."
