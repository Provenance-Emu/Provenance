import SwiftUI
import PVLookupTypes
import PVLookup

/// Data structure for selected artwork
struct ArtworkSelectionData {
    let metadata: ArtworkMetadata
    let previewImage: Image?

    init(metadata: ArtworkMetadata, previewImage: Image? = nil) {
        self.metadata = metadata
        self.previewImage = previewImage
    }
}
