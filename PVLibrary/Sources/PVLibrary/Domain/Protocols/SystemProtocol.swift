//
//  SystemProtocol.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 11/12/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public protocol SystemProtocol {
    associatedtype BIOSInfoProviderType: BIOSInfoProvider

    var name: String { get }
    var shortName: String { get }
    var shortNameAlt: String? { get }

    var identifier: String { get }

    var manufacturer: String { get }
    var releaseYear: Int { get }
    var bits: SystemBits { get }

    var openvgDatabaseID: Int { get }
    var headerByteSize: Int { get }
    var requiresBIOS: Bool { get }
    var options: SystemOptions { get }

    var BIOSes: [BIOSInfoProviderType]? { get }
    var extensions: [String] { get }

    var gameStructs: [Game] { get }
    var coreStructs: [Core] { get }
    var userPreferredCore: Core? { get }

    var usesCDs: Bool { get }
    var portableSystem: Bool { get }

    var supportsRumble: Bool { get }
    var screenType: ScreenType { get }
    var supported: Bool { get }
}

// MARK: Default Implimentations

extension SystemProtocol {
    public var options: SystemOptions {
        var systemOptions = [SystemOptions]()
        if usesCDs { systemOptions.append(.cds) }
        if portableSystem { systemOptions.append(.portable) }
        if supportsRumble { systemOptions.append(.rumble) }

        return SystemOptions(systemOptions)
    }
}
