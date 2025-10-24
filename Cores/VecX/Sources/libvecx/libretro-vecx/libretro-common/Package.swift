// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Libretro-Common",
    products: [
        .library(name: "Libretro-Common",
                 targets: ["Libretro-Common"]),
    ],
    targets: [
        .systemLibrary(
            name: "vfs",
            path: "vfs",
            pkgConfig: "vfs"
            // providers: [.brew(["sdl2"]), .apt(["libsdl2-dev"])]
            ),
        .target(
            name: "Libretro-Common", 
            dependencies: ["vfs"], path: "Libretro-Common"
            ),
        // // workaround for unsafeFlags from SDL <https://forums.swift.org/t/override-for-unsafeflags-in-swift-package-manager/45273/5>
        // .target(name: "CSDL2Wrapped", dependencies: ["CSDL2"]),
        // .target(name: "Minimal", dependencies: ["SDL2"], path: "Sources/Demos/Minimal"),
        // .target(name: "MetalApp", dependencies: ["SDL2"], path: "Sources/Demos/MetalApp",swiftSettings: [.define("METAL_ENABLED", .when(platforms: [.macOS]))]),
        // .testTarget(name: "CSDL2Tests", dependencies: ["CSDL2"])
    ]
)