// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LzhArchive",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LzhArchive",
            targets: ["LzhArchive"]),
    ],
    targets: [
        // MARK: - C compression Libs

        // ------------------------------------
        // MARK: - LzhArchive
        // ------------------------------------
        .target (
            name: "LzhArchive",
            dependencies: ["lhasa"],
            path: "Sources/LzhArchive/",
            sources: [
                "extract.c",
                "utf8.c",
                "LzhArchive.m",
            ],
            cSettings: [
                .headerSearchPath("../lhasa/"),
                .headerSearchPath("../lhasa/src"),
                .headerSearchPath("../lhasa/lib/"),
                .headerSearchPath("../lhasa/lib/public/"),
                .headerSearchPath("../"),
            ],
            linkerSettings: [
                .linkedLibrary("lzma")
            ]
        ),

        .testTarget(
            name: "LzhArchiveTests",
            dependencies: ["LzhArchive"]
        ),

        // ------------------------------------
        // MARK: - lhasa
        // ------------------------------------
        .target (
            name: "lhasa",
            path: "Sources/lhasa/",
            sources: Sources.lhasa,
            publicHeadersPath: "lib/public",
            cSettings: [
                .headerSearchPath("./"),
                .headerSearchPath("./lib"),
                .headerSearchPath("./lib/public"),
                .headerSearchPath("./src")

            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Wl,-segalign,4000"
                ])
            ]
        ),
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu17,
    cxxLanguageStandard: .cxx20
)

enum Sources {
    static var lhasa: [String] { [
        [
// These files are #include'd
//        "bit_stream_reader.c",
//        "lh_new_decoder.c",
//        "pma_common.c",
//        "tree_decode.c",

            "crc16.c",
            "ext_header.c",
            "lha_arch_unix.c",
            "lha_arch_win32.c",
            "lha_decoder.c",
            "lha_endian.c",
            "lha_file_header.c",
            "lha_input_stream.c",
            "lha_basic_reader.c",
            "lha_reader.c",
            "macbinary.c",
            "null_decoder.c",
            "lh1_decoder.c",
            "lh5_decoder.c",
            "lh6_decoder.c",
            "lh7_decoder.c",
            "lhx_decoder.c",
            "lk7_decoder.c",
            "lz5_decoder.c",
            "lzs_decoder.c",
            "pm1_decoder.c",
            "pm2_decoder.c"
        ].map { "lib/\($0)" },
        [
            // "extract.c",
            "filter.c",
            "list.c",
            "safe.c"
        ].map { "src/\($0)" }
    ].flatMap{ $0 }
    }
}
