#!/bin/bash

set -euxo pipefail

swift build
swift build -c release
