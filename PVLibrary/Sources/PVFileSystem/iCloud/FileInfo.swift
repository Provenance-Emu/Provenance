//
//  FileInfo.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/11/24.
//

import Foundation

struct FileInfo: Codable {
    let url: URL
    let name: String
    let modificationDate: Date?
    let creationDate: Date?
    let fileSize: Int
}
