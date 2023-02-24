// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "Provenance",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        // .library(
        //     name: "Provenance",
        //     targets: ["Provenance"])
    ],

    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(name: "PVLogging", path: "../PVLogging/"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.50.4"),
        .package(url: "https://github.com/tuist/XcodeProj.git", .upToNextMajor(from: "8.9.0")),
        .package(url: "https://github.com/apple/swift-format.git", .upToNextMajor(from: "0.50700.1")),
    ],

    // MARK: - Targets
    targets: [
        // // MARK: - PVSupport
        // .target(
        //     name: "PVSupport",
        //     dependencies: [
        //         .product(name: "PVLogging", package: "PVLogging")
        //     ],
        //     resources: [
        //         .process("Controller/AHAP/")
        //     ],
        //     linkerSettings: [
        //         .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
        //         .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
        //     ])
    .plugin(
      name: "Lint Source Code",
      capability: .command(
        intent: .custom(
          verb: "lint-source-code",
          description: "Lint source code for a specified target."
        )
      ),
      dependencies: [
        .target(name: "swift-format")
      ],
      path: "Plugins/LintPlugin"
    ),
    ]
)

/*
Swift Format
swift package plugin --allow-writing-to-package-directory swiftformat
swift package plugin --allow-writing-to-package-directory swiftformat --target MyLibrary --swiftversion 5.6 --verbose

*/
