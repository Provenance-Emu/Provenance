// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVRender",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PVRender",
            targets: ["PVRender"]),
        .library(
            name: "PVRender-Dynamic",
            type: .dynamic,
            targets: ["PVRender"]),
        .library(
            name: "PVRender-Static",
            type: .static,
            targets: ["PVRender"])
    ],
    dependencies: [
      .package(url: "https://github.com/Hi-Rez/Satin.git", .branch("master"))
    ],
    targets: [
        .target(
            name: "PVRender",
            dependencies: [
                "Satin"
            ]
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVRenderTests",
            dependencies: ["PVRender"],
            path: "Tests")
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .c17,
    cxxLanguageStandard: .cxx17
)
