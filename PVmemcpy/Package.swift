// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVmemcpy",
    platforms: [
        .iOS(.v17),
        .tvOS("15.4"),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVmemcpy",
            targets: ["PVmemcpy"]),
         .library(
             name: "PVmemcpy-Dynamic",
             type: .dynamic,
             targets: ["PVmemcpy"]),
         .library(
             name: "PVmemcpy-Static",
             type: .static,
             targets: ["PVmemcpy"])
    ],

    dependencies: [
        .package(url: "https://github.com/JoeMatt/Turbo-Base64.swift.git", branch: "master")
    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVmemcpy
        .target(
            name: "PVmemcpy",
            dependencies: [
                "Turbo-Base64.swift"
            ],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx20
)
