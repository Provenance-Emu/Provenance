//
//  ProvenanceApp.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/26/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//


import SwiftUI
import PVLibrary
import PVSupport
import PVEmulatorCore
import PVCoreBridge
import PVThemes
import PVSettings
import PVUIBase
import PVUIKit
import PVSwiftUI
import PVLogging
import Combine
import Perception
import RxSwift

class AppState: ObservableObject {
    @Published var bootupState: AppBootupState.State = .notStarted
    @Default(.useUIKit) var useUIKit
    let bootupStateManager = AppBootupState()
    let disposeBag = DisposeBag()
    
    var gameImporter: GameImporter?
    var gameLibrary: PVGameLibrary<RealmDatabaseDriver>?
    var libraryUpdatesController: PVGameLibraryUpdatesController?
    
    init() {
        bootupStateManager.currentState
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                self?.bootupState = state
            })
            .disposed(by: disposeBag)
        
        // Observe changes to useUIKit and trigger objectWillChange
        Defaults.observe(.useUIKit) { [weak self] change in
            self?.objectWillChange.send()
        }
        .tieToLifetime(of: self)
    }
    
    func initializeDatabase() {
        bootupStateManager.transition(to: .initializingDatabase)
        Task {
            do {
                try RomDatabase.initDefaultDatabase()
                bootupStateManager.transition(to: .databaseInitialized)
            } catch {
                bootupStateManager.transition(to: .error(error))
            }
        }
    }
    
    func initializeLibrary() {
        bootupStateManager.transition(to: .initializingLibrary)
        Task {
            await GameImporter.shared.initSystems()
            RomDatabase.reloadCache()
            bootupStateManager.transition(to: .completed)
        }
    }
}
