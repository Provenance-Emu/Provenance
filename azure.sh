#!/usr/bin/env bash

#WORKSPACE=${WORKSPACE:-$(pwd)}
#SCHEME=${SCHEME:-$(pwd)}
WORKSPACE=Provenance.xcworkspace
SCHEME=Provenance
PKGDIR="./packages-cache"
FLAGS="-workspace $WORKSPACE -scheme $SCHEME -clonedSourcePackagesDirPath $PKGDIR"

xcodebuild -resolvePackageDependencies $FLAGS
# xcodebuild $FLAGS
