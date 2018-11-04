#!/bin/bash
set -ev
echo travis release: pr = "${TRAVIS_PULL_REQUEST}" - branch = "${TRAVIS_BRANCH}"
if [ "${TRAVIS_PULL_REQUEST}" = "false" ]; then
  if [ "${TRAVIS_BRANCH}" = "master" ]; then
    ./gradlew publishApkRelease
  fi
fi
