// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PVLiveActivities",
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
            name: "PVLiveActivities",
            targets: ["PVLiveActivities"]
        )
    ],
    dependencies: [
        // No dependencies — ActivityKit is a system framework.
        // Intentionally lightweight so it can be imported by the main app
        // and the ProvenanceWidgets extension without pulling in Realm.
    ],
    targets: [
        .target(
            name: "PVLiveActivities",
            dependencies: []
        ),
        .testTarget(
            name: "PVLiveActivitiesTests",
            dependencies: ["PVLiveActivities"]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
