#!/bin/bash

set -e

script_path="$(pushd "$(dirname "$0")" >/dev/null; pwd)"
src_path="$(pushd "${script_path}/.." >/dev/null; pwd)"

die() { echo "$@" 1>&2 ; exit 1; }
info() { echo "===> $*"; }

docker_build() {
  declare name="$1"; shift
  declare path="$1"; shift
  declare args="$*"

  if [ "${DOCKER_REGISTRY}" != "" ]; then
    remote_name="${DOCKER_REGISTRY}/${name}"
  fi

  info "Building ${name} image..."
  if [ "${DOCKER_REGISTRY}" != "" ]; then
    docker_pull "${remote_name}" && docker tag "${remote_name}" "${name}" || true
  fi

  old_id=$(docker images -q "${name}")
  info "Old ${name} image id: ${old_id}"
  
  if [ "${DOCKERFILE}" != "" ]; then
    docker build ${args} -t "${name}" -f "${DOCKERFILE}" "${path}" || \
        die "Building ${name} image failed"
  else
    docker build ${args} -t "${name}" "${path}" || \
        die "Building ${name} image failed"
  fi

  new_id=$(docker images -q "${name}")
  info "New ${name} image id: ${new_id}"

  if [ "${DEBUG}" ] && [ "${new_id}" != "${old_id}" ]; then
    info "History for old id $old_id:"
    if [ "${old_id}" != "" ]; then
      docker history "$old_id"
    fi

    info "History for new id $new_id:"
    docker history "$new_id"
  fi

  if [ "${DOCKER_PUSH:-0}" != "0" ] && [ "${DOCKER_REGISTRY}" != "" ]; then
    docker tag "${name}" "${remote_name}"
    docker_push "${remote_name}"
  fi
}

# Due to https://github.com/docker/docker/issues/20316, we use
# https://github.com/tonistiigi/buildcache to generate a cache of the layer
# metadata for later builds.
my_buildcache() {
  if [ "$DOCKER_REGISTRY" != "" ]; then

    docker_path="/var/lib/docker"

    # Stupid hack for our AWS nodes, which have docker data on another volume
    if [ -d "/mnt/docker" ]; then
      docker_path="/mnt/docker"
    fi

    docker pull "${DOCKER_REGISTRY}/ci/buildcache" >/dev/null && \
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v ${docker_path}:/var/lib/docker \
      "${DOCKER_REGISTRY}/ci/buildcache" "$@"
  fi
}

docker_pull() {
  info "Attempting to pull '$1' image from registry..."
  (
    tmpdir=$(mktemp -d)
    docker pull "$1"
    (
      # In addition, pull the cached metadata and load it (buildcache)
      cd "${tmpdir}" && docker pull "$1-cache" && docker save "$1-cache" | \
        tar -xf -  && docker load -i ./*/layer.tar
    )
    rm -rf "${tmpdir}"
  ) || true
}

docker_push() {
  info "Pushing '$1' image to registry..."
  docker push "$1"
  # Create a cache of the layer metdata we need and push it as an image
  #docker rmi $1-cache 2>/dev/null || true
  my_buildcache save -g /var/lib/docker "$1" | gunzip -c | \
    docker import - "$1-cache" && \
    docker push "$1-cache"
}

docker_build $@
