//
//  iCloudSync.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/11/24.
//

import Foundation
import Combine

enum iCloudError: Error {
    case unableToAccessiCloudContainer
}

func getFilesFromiCloudContainer(path: String) async throws -> [FileInfo] {
    let fileManager = FileManager.default
    
    guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent(path) else {
        throw iCloudError.unableToAccessiCloudContainer
    }
    
    try fileManager.createDirectory(at: containerURL, withIntermediateDirectories: true, attributes: nil)
    
    try fileManager.startDownloadingUbiquitousItem(at: containerURL)
    
    let fileURLs = try fileManager.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey, .fileSizeKey], options: [.skipsHiddenFiles])
    
    return try fileURLs.map { url in
        let attributes = try url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey, .fileSizeKey])
        return FileInfo(
            url: url,
            name: url.lastPathComponent,
            modificationDate: attributes.contentModificationDate,
            creationDate: attributes.creationDate,
            fileSize: attributes.fileSize ?? 0
        )
    }
}
