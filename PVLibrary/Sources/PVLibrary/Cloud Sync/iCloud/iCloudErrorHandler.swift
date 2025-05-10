//
//  iCloudErrorHandler.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

public protocol iCloudErrorHandler {
    var allErrorSummaries: [String] { get async throws }
    var allFullErrors: [String] { get async throws }
    var allErrors: [iCloudSyncError] { get async }
    var isEmpty: Bool { get async }
    var numberOfErrors: Int { get async }
    func handleError(_ error: Error, file: URL?) async
    func clear() async
}
