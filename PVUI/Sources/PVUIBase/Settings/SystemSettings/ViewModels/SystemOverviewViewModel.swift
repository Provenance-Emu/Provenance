//
//  SystemOverviewViewModel.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/12/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVLibrary
import PVPrimitives
import PVSupport

struct SystemOverviewViewModel: Sendable {
    let title: String
    let identifier: String
    let gameCount: Int
    let cores: @Sendable () -> [Core]
    let preferredCore: Core?
    let bioses: [BIOSInfoProvider]?
}

extension SystemOverviewViewModel {
    init<S: SystemProtocol>(withSystem system: S) {
        title = system.name
        identifier = system.identifier
        gameCount = PVEmulatorConfiguration.gamesCount(forSystem: system)
        cores = { PVEmulatorConfiguration.cores(forSystem: system).mapToDomain() }
        bioses = system.BIOSes
        preferredCore = system.userPreferredCore
    }
    
    init<S: PVSystem>(withSystem system: S) {
        title = system.name
        identifier = system.identifier
        gameCount = system.games.count
        cores = { system.cores.mapToDomain() }
        bioses = system.BIOSes
        preferredCore = system.userPreferredCore
    }
}
