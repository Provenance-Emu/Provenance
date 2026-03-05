//
//  ImageFile.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData)
import SwiftData
import CoreGraphics

// NOTE: SwiftData @Model does not support inheritance between @Model classes,
// so ImageFile_Data cannot subclass File_Data. Fields are duplicated intentionally.
@Model
public class ImageFile_Data {
    // File data (duplicated from File_Data since @Model inheritance is unsupported)
    public var partialPath: String = ""
    public var md5Cache: String?
    public var createdDate: Date = Date()

    // Dimensions — stored as separate Floats for SwiftData compatibility
    public var width: Float = 0.0
    public var height: Float = 0.0

    // Display
    public var ratio: Float = 0.0
    public var layout: String = ""

    /// Convenience accessor derived from stored width/height
    public var cgSize: CGSize { CGSize(width: CGFloat(width), height: CGFloat(height)) }

    public init(partialPath: String, md5Cache: String? = nil, createdDate: Date = Date(),
                width: Float = 0, height: Float = 0, ratio: Float = 0, layout: String = "") {
        self.partialPath = partialPath
        self.md5Cache = md5Cache
        self.createdDate = createdDate
        self.width = width
        self.height = height
        self.ratio = ratio
        self.layout = layout
    }
}
#endif
