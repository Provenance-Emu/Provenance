import Foundation

/// Type of background animation embedded in a skin
public enum DeltaSkinBackgroundAnimationType: String, Codable {
    case frames
    case apng
    case gif
}

/// Animated background configuration parsed from skin info.json.
/// Placed under the orientation representation key (e.g. inside `iphone/edgeToEdge/portrait`).
///
/// Example JSON:
/// ```json
/// {
///   "backgroundAnimation": {
///     "type": "frames",
///     "frames": ["bg_f0.png", "bg_f1.png", "bg_f2.png"],
///     "fps": 8,
///     "loops": true
///   }
/// }
/// ```
public struct DeltaSkinBackgroundAnimation: Codable, Equatable {
    /// Animation type — `frames`, `apng`, or `gif`
    public let type: DeltaSkinBackgroundAnimationType

    /// Frame filenames for the `.frames` type
    public let frames: [String]?

    /// Single filename for `.apng` or `.gif` types
    public let file: String?

    /// Playback rate in frames per second (default 8)
    public let fps: Double?

    /// Whether to loop the animation (default true)
    public let loops: Bool?

    public init(
        type: DeltaSkinBackgroundAnimationType,
        frames: [String]? = nil,
        file: String? = nil,
        fps: Double? = nil,
        loops: Bool? = nil
    ) {
        self.type = type
        self.frames = frames
        self.file = file
        self.fps = fps
        self.loops = loops
    }
}
