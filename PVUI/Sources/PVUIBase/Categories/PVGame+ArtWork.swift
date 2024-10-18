public extension PVGame {
    var trueArtworkURL: String {
        return (customArtworkURL.isEmpty) ? originalArtworkURL : customArtworkURL
    }
}
