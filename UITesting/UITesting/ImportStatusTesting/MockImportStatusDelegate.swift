//
//  MockImportStatusDelegate.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/27/24.
//

import PVSwiftUI

class MockImportStatusDriverData: ObservableObject {
    @MainActor
    let gameImporter = MockGameImporter() //AppState.shared.gameImporter ?? GameImporter.shared
    @MainActor
    let pvgamelibraryUpdatesController: PVGameLibraryUpdatesController

    var isPresent: Bool = false
    
    @MainActor
    init() {
        pvgamelibraryUpdatesController = .init(gameImporter: gameImporter)
    }
}

extension MockImportStatusDriverData: ImportStatusDelegate {
    func dismissAction() {
        
    }
    
    func addImportsAction() {
        let importItems: [ImportQueueItem] = [
            .init(url: .init(string: "test.jag")!, fileType: .unknown)
        ]
        importItems.forEach {
            gameImporter.addImport($0)
        }
    }
    
    func forceImportsAction() {
        gameImporter.startProcessing()
    }
}
