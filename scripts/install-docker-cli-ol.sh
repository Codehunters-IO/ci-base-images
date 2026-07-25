#!/usr/bin/env bash
# Install Docker CLI + buildx on Oracle Linux 9 from Docker CE repo.
# microdnf lacks `config-manager`; drop the .repo file directly.
set -euo pipefail

PM="microdnf"
if ! command -v "${PM}" >/dev/null 2>&1; then
    PM="dnf"
fi

DOCKER_REPO_URL="https://download.docker.com/linux/centos/docker-ce.repo"
curl -fSL -o /etc/yum.repos.d/docker-ce.repo "${DOCKER_REPO_URL}"

"${PM}" install -y \
    docker-ce-cli \
    docker-buildx-plugin

"${PM}" clean all

docker --version
docker buildx version
echo "Docker CLI + buildx (Oracle Linux 9) installed."
