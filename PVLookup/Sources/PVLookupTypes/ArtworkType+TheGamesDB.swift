import Foundation

public extension ArtworkType {
    /// Initialize ArtworkType from TheGamesDB type and side strings
    init?(fromTheGamesDB type: String, side: String?) {
        switch type.lowercased() {
        case "boxart":
            if side?.lowercased() == "front" {
                self = .boxFront
            } else if side?.lowercased() == "back" {
                self = .boxBack
            } else {
                return nil
            }
        case "screenshot":
            self = .screenshot
        case "titlescreen":
            self = .titleScreen
        case "fanart":
            self = .fanArt
        case "banner":
            self = .banner
        case "clearlogo":
            self = .clearLogo
        default:
            self = .other
        }
    }
}
