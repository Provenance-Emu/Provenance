#!/bin/bash
set -ev
if [ "${TRAVIS_PULL_REQUEST}" = "false" ]; then
	./gradlew build  --configure-on-demand
else
	./gradlew assembleDebug  --configure-on-demand
fi
