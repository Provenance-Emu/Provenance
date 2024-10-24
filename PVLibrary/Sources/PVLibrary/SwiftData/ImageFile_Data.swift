//
//  ImageFile.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData)
import SwiftData

import CoreGraphics
import SwiftUI

#warning("Make subclass of File_Data")
@Model
public class ImageFile_Data {// : File_Data {
    
    internal var partialPath: String = ""
    
    internal var md5Cache: String?
    public private(set) var createdDate: Date = Date()
    
    // Dimensions
    public internal(set) var cgSize: CGSize = CGSize.zero
    public var width: Float { Float(cgSize.width) }
    public var height: Float { Float(cgSize.height) }
    
    // Display
    public var ratio: Float = 0.0
    
    public var layout: String = ""
    
    init(partialPath: String, md5Cache: String? = nil, createdDate: Date, cgSize: CGSize, ratio: Float, layout: String) {
        self.partialPath = partialPath
        self.md5Cache = md5Cache
        self.createdDate = createdDate
        self.cgSize = cgSize
        self.ratio = ratio
        self.layout = layout
    }
}
#endif
