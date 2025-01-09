//
//  BIOSWatcher.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/30/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import Combine
import PVLogging
import Perception
import PVFileSystem

@Perceptible
public final class BIOSWatcher: ObservableObject {
    public static let shared = BIOSWatcher()

    private let biosPath: URL
    private var directoryWatcher: DirectoryWatcher?

    //@ObservationIgnored
    private var newBIOSFilesContinuation: AsyncStream<[URL]>.Continuation?

    public var newBIOSFilesSequence: AsyncStream<[URL]> {
        AsyncStream { continuation in
            newBIOSFilesContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                self.newBIOSFilesContinuation = nil
            }
        }
    }

    private init() {
        biosPath = Paths.biosesPath
        setupDirectoryWatcher()
    }

    private func setupDirectoryWatcher() {
        directoryWatcher = DirectoryWatcher(directory: biosPath)

        Task {
            await watchForNewBIOSFiles()
        }
    }

    private func watchForNewBIOSFiles() async {
        guard let directoryWatcher = directoryWatcher else { return }

        for await files in directoryWatcher.completedFilesSequence {
            let newFiles = files.filter { file in
                // Check if this file is not already in the database
                let fileName = file.lastPathComponent
                return RomDatabase.sharedInstance.object(ofType: PVBIOS.self, wherePrimaryKeyEquals: fileName) == nil
            }

            if !newFiles.isEmpty {
                newBIOSFilesContinuation?.yield(newFiles)
            }
        }
    }
}
