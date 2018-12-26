#!/bin/bash

set -euo pipefail

if [[ -d "build/" ]]; then
    (set -x; rm -rf build/)
fi

if [[ -d "Carthage/" ]]; then
    (set -x; rm -rf Carthage/)
fi

if [[ -d "docs/" ]]; then
    (set -x; rm -rf docs/)
fi

if [[ -d "Pods/" ]]; then
    (set -x; rm -rf Pods/)
fi

if [[ -d ".build/" ]]; then
    (set -x; rm -rf .build/)
fi

if [[ -f "Cartfile.resolved" ]]; then
    (set -x; rm Cartfile.resolved)
fi

if [[ -f "docs.json" ]]; then
    (set -x; rm docs.json)
fi

if [[ -f "Package.resolved" ]]; then
    (set -x; rm Package.resolved)
fi

if [[ -f "SWCompression.framework.zip" ]]; then
    (set -x; rm SWCompression.framework.zip)
fi
