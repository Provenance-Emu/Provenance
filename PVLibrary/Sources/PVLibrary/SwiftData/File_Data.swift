//
//  File.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData) && !os(tvOS)
import SwiftData

@Model
public class File_Data {
    // Data
    internal var partialPath: String = ""

    internal var md5Cache: String?
    public private(set) var createdDate: Date = Date()
    
    init(partialPath: String, md5Cache: String? = nil, createdDate: Date) {
        self.partialPath = partialPath
        self.md5Cache = md5Cache
        self.createdDate = createdDate
    }
}
#endif
