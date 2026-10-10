import ProjectDescription

/// How the dev app consumes a core or a support framework.
/// Paths are repo-relative (the Tuist root is the repo root).
public enum CoreLink: Equatable {
    /// A dynamic product of a local Swift package.
    case package(path: String, product: String)
    /// A framework target of a hand-maintained `.xcodeproj`. Tuist can only depend on targets
    /// of projects it generates, so the project is listed in the workspace, the product is
    /// linked by name (Xcode schedules the producer as an implicit dependency) and a post
    /// script embeds it. See `DevSettings.embedProjectFrameworksScript`.
    case project(path: String, target: String, product: String)
    /// A `.framework` / `.xcframework` on disk. Tuist reads it at generate time, so it must exist.
    case prebuilt(path: String)

    /// Every repo-relative path this link needs (for the manifest checks).
    public var paths: [String] {
        switch self {
        case let .package(path, _): return [path, path + "/Package.swift"]
        case let .project(path, _, _): return [path]
        case let .prebuilt(path): return [path]
        }
    }
}

/// One audited core (see docs/superpowers/specs/2026-10-10-core-audit.md, KEEP rows) or a
/// non-core product every app embeds. Only how the app consumes it lives here.
public struct CoreProduct {
    public let id: String
    public let link: CoreLink
    /// Extra frameworks the app must embed (Mupen plugins, PVlibDolphin).
    public let embeds: [CoreLink]
    /// Platforms the shipping target links it on.
    public let platforms: Set<PlatformFilter>
    /// Aggregate target that builds the core's out-of-tree library ("BuildPVlibAzahar", "Make XCFrameworks").
    public let needsAggregate: String?

    public init(
        id: String,
        link: CoreLink,
        embeds: [CoreLink] = [],
        platforms: Set<PlatformFilter> = [.ios, .tvos],
        needsAggregate: String? = nil
    ) {
        self.id = id
        self.link = link
        self.embeds = embeds
        self.platforms = platforms
        self.needsAggregate = needsAggregate
    }

    /// `link` followed by `embeds`.
    public var links: [CoreLink] { [link] + embeds }
}

public extension CoreProduct {
    // MARK: KEEP cores (product names copied from Provenance.xcodeproj embed phases)

    static let mGBA = CoreProduct(id: "mgba", link: .package(path: "Cores/mGBA", product: "PVCoremGBA-Dynamic"))
    static let stella = CoreProduct(id: "stella", link: .package(path: "Cores/Stella", product: "PVStella-Dynamic"))

    // PVSNES9x.xcodeproj: target "PVSNES9x" builds PVSNES.framework, target "snes9x" builds snes9x.framework.
    static let snes9x = CoreProduct(
        id: "snes9x",
        link: .project(path: "Cores/snes9x/PVSNES9x.xcodeproj", target: "PVSNES9x", product: "PVSNES"),
        embeds: [.project(path: "Cores/snes9x/PVSNES9x.xcodeproj", target: "snes9x", product: "snes9x")]
    )
    static let fceu = CoreProduct(
        id: "fceu",
        link: .project(path: "Cores/FCEU/PVFCEU.xcodeproj", target: "PVFCEU", product: "PVFCEU")
    )
    static let genesis = CoreProduct(
        id: "genesis",
        link: .project(path: "Cores/Genesis-Plus-GX/PVGenesis.xcodeproj", target: "PVGenesis", product: "PVGenesis")
    )
    static let mupen64Plus = CoreProduct(
        id: "mupen64plus",
        link: .project(path: "Cores/Mupen64Plus/PVMupen64Plus.xcodeproj", target: "PVMupen64Plus", product: "PVMupen64Plus"),
        embeds: [
            .project(path: "Cores/Mupen64Plus/PVMupen64Plus.xcodeproj", target: "PVMupen64PlusRspHLE", product: "PVMupen64PlusRspHLE"),
            .project(path: "Cores/Mupen64Plus/PVMupen64Plus.xcodeproj", target: "PVMupen64PlusBridge", product: "PVMupen64PlusBridge"),
            .project(path: "Cores/Mupen64Plus/PVMupen64Plus.xcodeproj", target: "PVMupen64PlusVideoGlideN64", product: "PVMupen64PlusVideoGlideN64"),
            .project(path: "Cores/Mupen64Plus/PVMupen64Plus.xcodeproj", target: "PVMupen64PlusVideoRice", product: "PVMupen64PlusVideoRice"),
            .project(path: "Cores/Mupen64Plus/PVMupen64Plus.xcodeproj", target: "PVRSPCXD4", product: "PVRSPCXD4")
        ]
    )
    static let mednafen = CoreProduct(id: "mednafen", link: .package(path: "Cores/Mednafen", product: "PVCoreMednafen-Dynamic"))
    static let proSystem = CoreProduct(id: "prosystem", link: .package(path: "Cores/ProSystem", product: "PVProSystem-Dynamic"))
    static let picoDrive = CoreProduct(id: "picodrive", link: .package(path: "Cores/PicoDrive", product: "PVPicoDrive-Dynamic"))
    static let tgbDual = CoreProduct(id: "tgbdual", link: .package(path: "Cores/TGBDual", product: "PVTGBDual-Dynamic"))
    static let azahar = CoreProduct(
        id: "azahar",
        link: .project(path: "Cores/Azahar/PVAzahar.xcodeproj", target: "PVAzahar", product: "PVAzahar"),
        needsAggregate: "BuildPVlibAzahar"
    )
    // PVDolphin links PVlibDolphin.xcframework, which `Make XCFrameworks` (build_slice.py) produces.
    // Build.xcconfig excludes both from simulator SDKs; no focused app uses Dolphin yet.
    static let dolphin = CoreProduct(
        id: "dolphin",
        link: .project(path: "Cores/Dolphin/PVDolphin.xcodeproj", target: "PVDolphin", product: "PVDolphin"),
        embeds: [.prebuilt(path: "Cores/Dolphin/dolphin-ios/build/xcframework/PVlibDolphin.xcframework")],
        needsAggregate: "Make XCFrameworks"
    )

    // MARK: Non-core products every app embeds

    static let cheevos = CoreProduct(id: "pvcheevos", link: .package(path: "PVCheevos", product: "PVCheevos"))
    static let moltenVK = CoreProduct(id: "moltenvk", link: .package(path: "MoltenVK", product: "MoltenVK"))

    static let coreBridgeRetro = CoreProduct(
        id: "pvcorebridgeretro",
        link: .project(path: "PVCoreBridgeRetro/PVCoreBridgeRetro.xcodeproj", target: "PVCoreBridgeRetro", product: "PVCoreBridgeRetro")
    )

    /// Linked into every focused app.
    static let nonCore: [CoreProduct] = [.cheevos, .moltenVK, .coreBridgeRetro]

    /// Every row, for the manifest checks.
    static let all: [CoreProduct] = [
        .mGBA, .stella, .snes9x, .fceu, .genesis, .mupen64Plus, .mednafen,
        .proSystem, .picoDrive, .tgbDual, .azahar, .dolphin
    ] + nonCore
}
