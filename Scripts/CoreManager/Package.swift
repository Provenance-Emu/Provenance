// swift-tools-version: 5.9
// Package.swift — CoreManager CLI for libretro core management
//
// Usage:
//   cd Scripts/CoreManager
//   swift run CoreManager generate
//   swift run CoreManager validate
//   swift run CoreManager diff
//   swift run CoreManager bootstrap
//
// Build a release binary:
//   swift build -c release
//   .build/release/CoreManager --help
import PackageDescription

let package = Package(
    name: "CoreManager",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "CoreManager",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/CoreManager"
        ),
        .testTarget(
            name: "CoreManagerTests",
            dependencies: ["CoreManager"],
            path: "Tests/CoreManagerTests"
        ),
    ]
)
