#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 || $1 != "-T"  ]]; then
    echo "=> Downloading files used for testing"

    (set -x ; git submodule update --init --recursive)
    if [ $? -ne 0 ]; then
        echo "ERROR: unable to update git submodule"
        exit 1
    fi
fi

echo "=> Downloading dependency (BitByteData) using Carthage"
(set -x; carthage bootstrap)
