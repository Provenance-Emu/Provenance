// swift-tools-version:5.9

import PackageDescription
import Foundation

let SCADE_SDK = ProcessInfo.processInfo.environment["SCADE_SDK"] ?? ""

let package = Package(
    name: "ScadeProject",
    platforms: [
        .macOS(.v11),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "ScadeProject",
            type: .static,
            targets: [
                "ScadeProject"
            ]
        )
    ],
    dependencies: [
//    	package(name: "PVSupport", path: "../PVSupport/")
//		.package(name: "PVAudio", path: "../PVAudio/"),
//        .package(name: "PVLogging", path: "../PVLogging/")
    ],
    targets: [
        .target(
            name: "ScadeProject",
            dependencies: [
//				"PVAudio",
//				"PVLogging",
//				"PVSupport"
     		],
            exclude: ["main.page"],
            swiftSettings: [
                .unsafeFlags(["-F", SCADE_SDK], .when(platforms: [.macOS, .iOS])),
                .unsafeFlags(["-I", "\(SCADE_SDK)/include"], .when(platforms: [.android])),
            ]
        )
    ]
)
