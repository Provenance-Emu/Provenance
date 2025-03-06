//
//  MockImportStatusDelegate.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/27/24.
//

import PVSwiftUI

public class MockImportStatusDriverData: ObservableObject {
    @MainActor
    public let gameImporter = MockGameImporter() //AppState.shared.gameImporter ?? GameImporter.shared
    @MainActor
    public let pvgamelibraryUpdatesController: PVGameLibraryUpdatesController

    public var isPresent: Bool = false

    @MainActor
    public init() {
        pvgamelibraryUpdatesController = .init(gameImporter: gameImporter)
    }
}

extension MockImportStatusDriverData: ImportStatusDelegate {
    public func dismissAction() {

    }

    public func addImportsAction() {
        let importItems: [ImportQueueItem] = [
            .init(url: .init(string: "test.jag")!, fileType: .unknown)
        ]
        importItems.forEach {
            gameImporter.addImport($0)
        }
    }

    public func forceImportsAction() {
        gameImporter.startProcessing()
    }

    public func didSelectSystem(_ system: SystemIdentifier, for item: ImportQueueItem) {
        if gameImporter.processingState == .idle {
            gameImporter.startProcessing()
        } else if gameImporter.processingState == .paused {
            if let concreteImporter = gameImporter as? GameImporter {
                Task {
                    await concreteImporter.processItem(item)
                }
            }
        }
    }
}
