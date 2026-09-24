// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PVQuickLookSupport",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "PVQuickLookSupport", targets: ["PVQuickLookSupport"])
    ],
    dependencies: [
        // Realm-free on purpose: this links into QLThumbnailProvider / QLPreviewProvider
        // processes. Library data comes from the App Group index written by the host.
        .package(path: "../PVAppIntents"),
    ],
    targets: [
        .target(
            name: "PVQuickLookSupport",
            dependencies: [
                .product(name: "PVLibrarySnapshot", package: "PVAppIntents"),
            ]
        ),
        .testTarget(
            name: "PVQuickLookSupportTests",
            dependencies: ["PVQuickLookSupport", .product(name: "PVLibrarySnapshot", package: "PVAppIntents")]
        ),
    ],
    swiftLanguageModes: [.v5],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx20
)
