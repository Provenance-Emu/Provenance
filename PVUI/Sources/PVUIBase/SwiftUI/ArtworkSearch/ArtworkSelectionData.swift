import SwiftUI
import PVLookupTypes
import PVLookup

/// Data structure for selected artwork
public struct ArtworkSelectionData {
    public let metadata: ArtworkMetadata
    public let previewImage: Image?

    public init(metadata: ArtworkMetadata, previewImage: Image? = nil) {
        self.metadata = metadata
        self.previewImage = previewImage
    }
}
