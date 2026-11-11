import Foundation

struct GeometryOptions {
    var layout = OverlayLayoutFile.empty
    var gameMD5: String?
    var shownToggles: Set<OverlayAction> = []

    init(_ args: [String]) throws {
        var arguments = ArraySlice(args)
        guard arguments.popFirst() == "--geometry" else { throw Failure.usage }
        while let argument = arguments.popFirst() {
            switch argument {
            case "--layout-file":
                guard let path = arguments.popFirst() else { throw Failure.usage }
                layout = try JSONDecoder().decode(OverlayLayoutFile.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
                guard layout.version == OverlayLayoutFile.currentVersion else { throw Failure.unsupportedVersion(layout.version) }
            case "--game-md5":
                guard let md5 = arguments.popFirst(), !md5.isEmpty else { throw Failure.usage }
                gameMD5 = md5
            case "--keypad":
                shownToggles.insert(.keypad)
            default:
                throw Failure.usage
            }
        }
    }

    enum Failure: LocalizedError {
        case usage
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .usage: return "Usage: export-skins.sh [--geometry [--layout-file PATH] [--game-md5 MD5] [--keypad]]"
            case .unsupportedVersion(let version): return "Unsupported legacy layout file version: \(version)"
            }
        }
    }
}

struct GeometryProfile {
    let name: String
    let orientation: OverlayOrientation
    let canvas: OverlayCanvas

    private init(_ name: String, _ orientation: OverlayOrientation, _ width: CGFloat, _ height: CGFloat,
                 top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) {
        self.name = name
        self.orientation = orientation
        self.canvas = OverlayCanvas(size: CGSize(width: width, height: height),
                                    safeArea: OverlayInsets(top: top, left: left, bottom: bottom, right: right))
    }

    // Reference devices from the Format 2 bake trait table. Orientation is explicit for split view.
    static let all: [Self] = [
        .init("iphone-standard-portrait", .portrait, 414, 736),
        .init("iphone-standard-landscape", .landscape, 736, 414),
        .init("iphone-edgeToEdge-portrait", .portrait, 393, 852, top: 59, bottom: 34),
        .init("iphone-edgeToEdge-landscape", .landscape, 852, 393, left: 59, bottom: 21, right: 59),
        .init("ipad-standard-portrait", .portrait, 834, 1194, top: 24, bottom: 20),
        .init("ipad-standard-landscape", .landscape, 1194, 834, top: 24, bottom: 20),
        .init("ipad-splitView-portrait", .portrait, 639, 1194, top: 24, bottom: 20),
        .init("ipad-splitView-landscape", .landscape, 639, 834, top: 24, bottom: 20),
        .init("tv-standard-landscape", .landscape, 1920, 1080, top: 60, left: 80, bottom: 60, right: 80)
    ]
}

struct GeometryReference: Encodable {
    struct Group: Encodable {
        struct Control: Encodable {
            let id: String
            let kind: OverlayControlKind
            let frame: CGRect
            let hitFrame: CGRect
        }

        let id: String
        let frame: CGRect
        let opacity: CGFloat
        let controls: [Control]

        init(_ group: ResolvedGroup) {
            id = group.id
            frame = group.frame
            opacity = group.opacity
            controls = group.controls.map {
                Control(id: $0.id, kind: $0.control.kind, frame: $0.frame, hitFrame: $0.hitFrame)
            }
        }
    }

    let pad: OverlayPadKind
    let profile: String
    let layoutKey: String
    let groups: [Group]
    let screens: [CGRect]

    init(template: OverlayTemplate, profile: GeometryProfile, options: GeometryOptions) {
        pad = template.padKind
        self.profile = profile.name
        layoutKey = pad.storageKey(for: template.orientation)
        let overrides = options.layout.overrides(for: layoutKey, gameMD5: options.gameMD5)
        let result = OverlayLayoutEngine.resolve(template: template, canvas: profile.canvas, overrides: overrides,
                                                 gameAspect: 4.0 / 3.0, shownToggles: options.shownToggles)
        groups = result.groups.map(Group.init)
        screens = result.screenFrames
    }
}
