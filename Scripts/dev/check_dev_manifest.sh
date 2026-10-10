#!/bin/bash
# Compiles Tuist/ProjectDescriptionHelpers with Dev/Tests/ManifestChecks/main.swift against the
# ProjectDescription.framework of the pinned Tuist (.mise.toml) and runs the checks.
# Exit: 0 all checks pass, 1 a check failed, 2 setup error.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TUIST_DIR="$(mise where tuist 2>/dev/null || true)"
FRAMEWORKS="${TUIST_DIR}/bin"
if [ ! -d "${FRAMEWORKS}/ProjectDescription.framework" ]; then
    echo "check_dev_manifest: ProjectDescription.framework not found under '${FRAMEWORKS}' (run: mise install)" >&2
    exit 2
fi

OUT="$(mktemp -d "${TMPDIR:-/tmp}/dev-manifest.XXXXXX")"
trap 'rm -rf "$OUT"' EXIT

xcrun swiftc -swift-version 5 \
    -F "${FRAMEWORKS}" -framework ProjectDescription \
    -Xlinker -rpath -Xlinker "${FRAMEWORKS}" \
    "${ROOT}"/Tuist/ProjectDescriptionHelpers/*.swift \
    "${ROOT}/Dev/Tests/ManifestChecks/main.swift" \
    -o "${OUT}/manifest-checks" || exit 2

"${OUT}/manifest-checks" "${ROOT}"
