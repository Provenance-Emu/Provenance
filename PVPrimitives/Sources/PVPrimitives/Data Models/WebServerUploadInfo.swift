//
//  WebServerUploadInfo.swift
//  PVPrimitives
//
//  Created by Joseph Mattiello on 4/26/25.
//

import Foundation

public struct WebServerUploadInfo: Identifiable, Equatable {
    public let filename: String
    public let progress: Double
    public let totalBytes: Int
    public let transferredBytes: Int
    public let currentFile: String
    public let queueLength: Int
    public let bytesTransferred: Int
    
    public var id: String { filename }
    
    public init(filename: String, progress: Double, totalBytes: Int, transferredBytes: Int, currentFile: String, queueLength: Int, bytesTransferred: Int) {
        self.filename = filename
        self.progress = progress
        self.totalBytes = totalBytes
        self.transferredBytes = transferredBytes
        self.currentFile = currentFile
        self.queueLength = queueLength
        self.bytesTransferred = bytesTransferred
    }
}
