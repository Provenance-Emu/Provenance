#!/usr/bin/env bash
# Export the model and family templates on macOS without building the UIKit host.
set -euo pipefail

tools_dir="$(cd "$(dirname "$0")" && pwd)"
source_dir="$tools_dir/../Sources/PVTouchOverlay"
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/pv-overlay-export.XXXXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT

mkdir "$scratch_dir/Sources"
cp "$tools_dir/"*.swift "$scratch_dir/Sources/"
for directory in Bindings Families Layout Model; do
    cp -R "$source_dir/$directory" "$scratch_dir/Sources/"
done

cat > "$scratch_dir/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OverlayTemplateExport",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/Provenance-Emu/PVSystems.git", exact: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "OverlayTemplateExport",
            dependencies: [.product(name: "PVSystems", package: "PVSystems")],
            path: "Sources"
        )
    ],
    swiftLanguageModes: [.v5]
)
SWIFT

xcrun swift run --package-path "$scratch_dir" OverlayTemplateExport "$@"
