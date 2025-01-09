// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVAudio",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVAudio",
            targets: ["PVAudio"]),
         .library(
             name: "PVAudio-Dynamic",
             type: .dynamic,
             targets: ["PVAudio"]),
         .library(
             name: "PVAudio-Static",
             type: .static,
             targets: ["PVAudio"])
    ],

    dependencies: [
        .package(name: "PVLogging", path: "../PVLogging/"),
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.0.0"),

    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVAudio
        .target(
            name: "PVAudio",
            dependencies: [
                "RingBuffer",
                "PVRingBuffer",
                "AppleRingBuffer",
                "OERingBuffer",
                "CARingBuffer",
                "PVLogging"
            ],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        // MARK: - RingBuffer Protocol
        .target(
            name: "RingBuffer",
            dependencies: [
                "PVLogging"
            ],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        // -----------------------------------------
        // MARK: - RingBuffer Implementations
        //==========================================
        // MARK: - PVRingBuffer
        .target(
            name: "PVRingBuffer",
            dependencies: [
                "RingBuffer",
                "PVLogging",
                .product(name: "Atomics", package: "swift-atomics")

            ],
            path: "Sources/Ring Buffers/PVRingBuffer",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        // MARK: - AppleRingBuffer
        .target(
            name: "AppleRingBuffer",
            dependencies: [
                "RingBuffer",
                "PVLogging"
            ],
            path: "Sources/Ring Buffers/AppleRingBuffer",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        // MARK: - OERingBuffer
        .target(
            name: "OERingBuffer",
            dependencies: [
                "RingBuffer",
                "PVLogging"
            ],
            path: "Sources/Ring Buffers/OERingBuffer",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        // MARK: - CARingBuffer
        .target(
            name: "CARingBuffer",
            dependencies: [
                "RingBuffer",
                "PVLogging"
            ],
            path: "Sources/Ring Buffers/CARingBuffer",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        // -----------------------------------------
        // MARK: - Tests
        .testTarget(
            name: "PVAudioTests",
            dependencies: ["PVAudio", "OERingBuffer", "PVRingBuffer", "AppleRingBuffer"]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx20
)
