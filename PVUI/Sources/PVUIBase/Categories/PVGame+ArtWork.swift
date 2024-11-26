import PVLibrary
import UIKit

public extension PVGame {
    var trueArtworkURL: String {
        return (customArtworkURL.isEmpty) ? originalArtworkURL : customArtworkURL
    }
    
    public func fetchArtworkFromCache() async -> UIImage?  {
        let trueArtworkURL = self.trueArtworkURL
        return await PVMediaCache.shareInstance().image(forKey: trueArtworkURL)
    }
}
