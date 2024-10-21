//
//  Store.swift
//  Message in a Bottle
//
//  Created by Drew McCormack on 09/02/2023.
//

import Foundation
import SwiftUI
import SwiftCloudDrive

extension RootRelativePath {
    static let textFile = Self(path: "text.txt")
}

@MainActor
class Store: ObservableObject {
    @Published var text: String = "" {
        didSet {
            save()
        }
    }
    
    private var drive: CloudDrive?

    init() {
        Task {
            do {
                self.drive = try await CloudDrive()
                drive?.observer = self
                try await loadText()
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    private func loadText() async throws {
        guard let drive else { throw Error.cloudDriveNotSetup }
        if try await drive.fileExists(at: .textFile) {
            let data = try await drive.readFile(at: .textFile)
            text = String(data: data, encoding: .utf8) ?? ""
        }
    }
    
    private func save() {
        Task {
            do {
                try await saveText()
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    private func saveText() async throws {
        guard let drive else { throw Error.cloudDriveNotSetup }
        guard let data = text.data(using: .utf8) else {
            throw Error.failedToGenerateDataFromText
        }
        try await drive.writeFile(with: data, at: .textFile)
    }
    
    enum Error: Swift.Error {
        case cloudDriveNotSetup
        case failedToGenerateDataFromText
    }
}

extension Store: CloudDriveObserver {
    
    nonisolated func cloudDriveDidChange(_ drive: CloudDrive, rootRelativePaths: [SwiftCloudDrive.RootRelativePath]) {
        Task {
            try? await loadText()
        }
    }
    
}
