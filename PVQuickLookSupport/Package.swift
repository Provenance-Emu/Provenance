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
        .library(
            name: "PVQuickLookSupport",
            targets: ["PVQuickLookSupport"]
        )
    ],
    dependencies: [
        .package(path: "../PVLibrary"),
        .package(path: "../PVHashing"),
        .package(url: "https://github.com/realm/realm-swift.git", from: "20.0.0"),
    ],
    targets: [
        // MARK: - PVQuickLookSupport
        .target(
            name: "PVQuickLookSupport",
            dependencies: [
                "PVLibrary",
                "PVHashing",
                .product(name: "RealmSwift", package: "realm-swift"),
            ]
        ),
        // MARK: - Tests
        .testTarget(
            name: "PVQuickLookSupportTests",
            dependencies: ["PVQuickLookSupport"]
        ),
    ],
    swiftLanguageModes: [.v5],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx20
)
