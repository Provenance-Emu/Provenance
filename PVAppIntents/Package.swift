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
        )
    ],
    dependencies: [
        // No external dependencies — entity stores are populated by the host app;
        // this module intentionally has no Realm dependency so it can compile
        // inside widget and Siri extensions without the full PVLibrary stack.
        // The host app bridges PVGame/PVSystem objects into the value-type entities.
    ],
    targets: [
        .target(
            name: "PVAppIntents",
            dependencies: []
        ),
        .testTarget(
            name: "PVAppIntentsTests",
            dependencies: ["PVAppIntents"]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx20
)
