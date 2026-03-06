//
//  File.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

import SwiftData

@Model
public class File_Data {
    // Data
    public var partialPath: String = ""
    public var md5Cache: String?
    public var createdDate: Date = Date()

    public init(partialPath: String, md5Cache: String? = nil, createdDate: Date = Date()) {
        self.partialPath = partialPath
        self.md5Cache = md5Cache
        self.createdDate = createdDate
    }
}
