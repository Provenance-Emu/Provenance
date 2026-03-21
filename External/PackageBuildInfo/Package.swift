// swift-tools-version: 6.0
/// Local fork of [PackageBuildInfo](https://github.com/DimaRU/PackageBuildInfo): uses a Swift `git` driver that discards stderr so fsmonitor / hook noise cannot corrupt generated `packageBuildInfo.swift`.
import PackageDescription

let package = Package(
    name: "PackageBuildInfo",
    products: [
        .plugin(name: "PackageBuildInfoPlugin", targets: ["PackageBuildInfoPlugin"])
    ],
    targets: [
        .executableTarget(
            name: "PackageBuildInfo",
            path: "Sources/PackageBuildInfo"
        ),
        .plugin(
            name: "PackageBuildInfoPlugin",
            capability: .buildTool(),
            dependencies: ["PackageBuildInfo"]
        )
    ]
)
