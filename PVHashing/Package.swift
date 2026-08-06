// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

#if os(Linux)
let checksumDep: [Package.Dependency] = []
let checksumTarget: [Target.Dependency] = []
#else
let checksumDep: [Package.Dependency] = [
    .package(url: "https://github.com/JoeMatt/Checksum.git", from: "1.1.1"),
]
let checksumTarget: [Target.Dependency] = [
    "Checksum",
]
#endif

let package = Package(
    name: "PVHashing",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVHashing",
            targets: ["PVHashing"]
        )
    ],
    dependencies: [
        .package(path: "../PVLogging"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ] + checksumDep,
    targets: [
        .target(
            name: "PVHashing",
            dependencies: [
                "PVLogging",
                .product(name: "Crypto", package: "swift-crypto"),
            ] + checksumTarget
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVHashingTests",
            dependencies: ["PVHashing"],
            resources: [ .copy("Resources/testFile.txt") ]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu17,
    cxxLanguageStandard: .gnucxx20
)
