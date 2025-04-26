//
//  WebServerUploadInfo.swift
//  PVPrimitives
//
//  Created by Joseph Mattiello on 4/26/25.
//

import Foundation

public struct WebServerUploadInfo: Identifiable, Equatable {
    public let id = UUID()
    public let progress: Double
    public let totalBytes: Int
    public let transferredBytes: Int
    public let currentFile: String
    public let queueLength: Int
    public let bytesTransferred: Int
    
    public init(progress: Double, totalBytes: Int, transferredBytes: Int, currentFile: String, queueLength: Int, bytesTransferred: Int) {
        self.progress = progress
        self.totalBytes = totalBytes
        self.transferredBytes = transferredBytes
        self.currentFile = currentFile
        self.queueLength = queueLength
        self.bytesTransferred = bytesTransferred
    }
}
