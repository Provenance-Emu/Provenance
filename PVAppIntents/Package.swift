// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PVAppIntents",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVAppIntents",
            targets: ["PVAppIntents"]
        ),
        /// The widgets' App Group snapshot (`widget.*` keys) and the Quick Look
        /// library index. Dependency-free and UI-framework-free so any app
        /// extension can link it and read library data without opening Realm.
        /// "Legacy" because its module name collides with the shared
        /// PVLibrarySnapshot package that Top Shelf now reads.
        .library(
            name: "PVLibrarySnapshotLegacy",
            targets: ["PVLibrarySnapshotLegacy"]
        ),
        /// Provenance's configuration of the shared PVLibrarySnapshot package
        /// (re-exported). The app writes that snapshot; Top Shelf reads it.
        .library(
            name: "PVLibrarySnapshotConfig",
            targets: ["PVLibrarySnapshotConfig"]
        )
    ],
    dependencies: [
        // No Realm dependency: entity stores are populated by the host app, so
        // these modules compile inside widget, Siri and Top Shelf extensions
        // without the full PVLibrary stack. The host app bridges PVGame/PVSystem
        // objects into the value-type entities.
        // Shared with iCube and iFly; system frameworks only.
        .package(url: "https://github.com/Provenance-Emu/PVLibrarySnapshot.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "PVLibrarySnapshotLegacy",
            dependencies: []
        ),
        .target(
            name: "PVLibrarySnapshotConfig",
            dependencies: [.product(name: "PVLibrarySnapshot", package: "PVLibrarySnapshot")]
        ),
        .target(
            name: "PVAppIntents",
            dependencies: ["PVLibrarySnapshotLegacy"]
        ),
        .testTarget(
            name: "PVAppIntentsTests",
            dependencies: ["PVAppIntents", "PVLibrarySnapshotLegacy"]
        ),
        // Separate from PVAppIntentsTests: the legacy and shared modules declare
        // the same type names, so no test file may import both.
        .testTarget(
            name: "PVLibrarySnapshotConfigTests",
            dependencies: ["PVLibrarySnapshotConfig"]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
