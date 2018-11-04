#!/bin/sh
# This script can be used to locally check and debug
# the linux build process outside of CI.
# This should be run from the root directory: `./workflow/local_docker_build.sh`

set -e

flavor=${1:-linux}

docker build -t ci/realm-object-server:build .

docker run -it --rm \
  -u $(id -u) \
  -v "${HOME}:${HOME}" \
  -e HOME="${HOME}" \
  -v /etc/passwd:/etc/passwd:ro \
  -v $(pwd):/source \
  -w /source \
  ci/realm-object-server:build \
  ./workflow/test_coverage.sh ${flavor}
