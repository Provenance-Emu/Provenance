// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import os.log
import PackageDescription

let env: [String: Bool] = [
    "JIT_ENABLED": false,
    "JIT_COMBINED_TARGET": false,
    "MACOS_USE_OPENGL": false,
    "USE_LOCAL_DELTACORE": true,
    "USE_CXX_INTEROP": false,
    "USE_CXX_MODULES": false,
    "INHIBIT_UPSTREAM_WARNINGS": false,
    "STATIC_LIBRARY": false,
]

let activeCores: [String: Bool] = [
    "DS": true,
    "GBA": false,
    "GBC": false,
    "GPGX": false,
	"mGBA": false,
    "MelonDS": false,
    "N64": false,
    "NES": false,
    "SNES": false,
]

let allCores: [String] = [""] + activeCores.map { $0.key }

let activedCores = activeCores.filter { $0.value }.map { $0.key }

print_cores()

func envBool(_ key: String) -> Bool {
    guard let value = ProcessInfo.processInfo.environment[key] else { return env[key, default: true] }
    let trueValues = ["1", "on", "true", "yes"]
    return trueValues.contains(value.lowercased())
}

let JIT_ENABLED = envBool("JIT_ENABLED")
let JIT_COMBINED_TARGET = envBool("JIT_COMBINED_TARGET")
let MACOS_USE_OPENGL = envBool("MACOS_USE_OPENGL")
let USE_LOCAL_DELTACORE = envBool("USE_LOCAL_DELTACORE")
let USE_CXX_INTEROP = envBool("USE_CXX_INTEROP")
let USE_CXX_MODULES = envBool("USE_CXX_MODULES")
let INHIBIT_UPSTREAM_WARNINGS = envBool("INHIBIT_UPSTREAM_WARNINGS")
let STATIC_LIBRARY = envBool("STATIC_LIBRARY")

let cHeaderSearchPaths: [CSetting] = []

let cxxHeaderSearchPaths: [CXXSetting] = []

// MARK: - C Settings

var cSettings: [CSetting] = [] + cHeaderSearchPaths

// MARK: - CXX Settings

var cxxSettings: [CXXSetting] = [] + cxxHeaderSearchPaths

// MARK: - Swift Settings

var swiftSettings: [SwiftSetting] = activedCores.map { $0.uppercased() }.map { name -> SwiftSetting in
    let name = "WANT_" + name
    return .define(name)
}

// MARK: - Linker Settings

var linkerSetings: [LinkerSetting] = [
    .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
    .linkedFramework("AVFoundation", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
    .linkedFramework("GLKit", .when(platforms: [.iOS, .tvOS])),
    .linkedFramework("OpenGLES", .when(platforms: [.iOS, .tvOS])),
    .linkedFramework("OpenGL", .when(platforms: [.macOS, .macCatalyst])),
]

if JIT_ENABLED {}

if JIT_COMBINED_TARGET {}

if MACOS_USE_OPENGL {}

if USE_CXX_MODULES {
    let cModules: CSetting = .unsafeFlags([
        "-fmodules",
        "-fcxx-modules",
    ])

    let cxxModules: CXXSetting = .unsafeFlags([
        "-fmodules",
        "-fcxx-modules",
    ])

    cSettings.append(cModules)
    cxxSettings.append(cxxModules)

    cxxSettings.append(
        CXXSetting.headerSearchPath("include"))

    swiftSettings.append(
        SwiftSetting.unsafeFlags(["-Xfrontend", "-enable-cxx-interop"]))

    linkerSetings.append(
        .linkedLibrary("stdc++"))
}

if INHIBIT_UPSTREAM_WARNINGS {
    cSettings.append(.unsafeFlags([
        "-w",
    ]))
    cxxSettings.append(.unsafeFlags([
        "-w",
    ]))
}

if STATIC_LIBRARY {
    cSettings.append(.define("STATIC_LIBRARY", to: "1"))
    cxxSettings.append(.define("STATIC_LIBRARY", to: "1"))
} else {
    cSettings.append(.define("STATIC_LIBRARY", to: "1", .when(platforms: [.wasi])))
    cxxSettings.append(.define("STATIC_LIBRARY", to: "1", .when(platforms: [.wasi])))
}

let core_packages: [Package.Dependency] = activedCores.map { shortName -> Package.Dependency in

    let fullName: String = shortName + "DeltaCore"
    return .package(path: fullName)
}

print(core_packages.map {
    String(describing: $0)
}.joined(separator: "\n"))

let package_dependencies: [Package.Dependency] = [.package(path: "DeltaCore")] + core_packages

let target_dependencies: [Target.Dependency] = activedCores.map {
    let name = "\($0)DeltaCore"
    return .byNameItem(name: name, condition: nil)
}

let exclude: [String] = allCores.map { "\($0)DeltaCore" }

let package = Package(
    name: "DeltroidCores",

    defaultLocalization: "en",

    platforms: [
        .iOS(.v12),
        .macOS(.v11),
        .tvOS(.v12),
        .macCatalyst(.v13),
    ],

    products: [
        .library(
            name: "DeltroidCores",
            targets: ["DeltroidCores"]
        ),
        .library(
            name: "DeltroidCores-Static",
            type: .static,
            targets: ["DeltroidCores"]
        ),
        .library(
            name: "DeltroidCores-Dynamic",
            type: .dynamic,
            targets: ["DeltroidCores"]
        ),
    ],

    dependencies: package_dependencies,

    targets: [
        // // MARK: - DeltroidCores

        .target(
            name: "DeltroidCores",
            dependencies: target_dependencies,
            path: "",
            exclude: exclude,
            sources: [
                "Cores.swift",
            ],
            cSettings: cSettings,
            cxxSettings: cxxSettings,
            swiftSettings: swiftSettings,
            linkerSettings: linkerSetings
        ),

        // .testTarget(
        //     name: "DeltroidCoresTests",
        //     dependencies: ["DeltroidCores"]
        // ),
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .c11,
    cxxLanguageStandard: .cxx14
)

// MARK: - - Helpers

extension String {
    func hasAnySuffix(_ suffixes: [String]) -> Bool { suffixes.first(where: { $0.hasSuffix($0) }) != nil }
}

extension Array where Element == Target.Dependency {
    func dependencyNames() -> [String] {
        map { dependency -> String in
            switch dependency {
            case let .byNameItem(name, _): return name
            case let .productItem(name, _, _, _): return name
            case let .targetItem(name, _): return name
            @unknown default: fatalError("Unknown case \(String(describing: dependency))")
            }
        }
    }
}

func print_cores() {
    let message = activeCores.map {
        let shortName: String = $0.key
        let fullName: String = shortName + "DeltaCore"

        let enabled: Bool = $0.value
        let emoji: String = (enabled ? "✅" : "❌")

        return "\(fullName) \(emoji)"
    }.joined(separator: "\n")

    os_log(.info, "%@", message)
}
