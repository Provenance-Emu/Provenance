#!/bin/bash
# Compiles Tuist/ProjectDescriptionHelpers with Dev/Tests/ManifestChecks/main.swift against the
# ProjectDescription.framework of the pinned Tuist (.mise.toml) and runs the checks.
# Exit: 0 all checks pass, 1 a check failed, 2 setup error.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TUIST_DIR="$(mise where tuist 2>/dev/null || true)"
PD=""
if [ -n "${TUIST_DIR}" ]; then
    PD="$(find "${TUIST_DIR}" -maxdepth 4 -type d -name ProjectDescription.framework 2>/dev/null | head -1)"
fi
if [ -z "${PD}" ]; then
    echo "check_dev_manifest: ProjectDescription.framework not found under '${TUIST_DIR}' (run: mise install)" >&2
    exit 2
fi
FRAMEWORKS="$(dirname "${PD}")"

OUT="$(mktemp -d "${TMPDIR:-/tmp}/dev-manifest.XXXXXX")"
trap 'rm -rf "$OUT"' EXIT

xcrun swiftc -swift-version 5 \
    -F "${FRAMEWORKS}" -framework ProjectDescription \
    -Xlinker -rpath -Xlinker "${FRAMEWORKS}" \
    "${ROOT}"/Tuist/ProjectDescriptionHelpers/*.swift \
    "${ROOT}/Dev/Tests/ManifestChecks/main.swift" \
    -o "${OUT}/manifest-checks" || exit 2

"${OUT}/manifest-checks" "${ROOT}"
