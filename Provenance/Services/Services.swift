//
//  Services.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/24/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
// import Promises

struct ServicesOptions: OptionSet {
    let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let iOS = ServicesOptions(rawValue: 1 << 0)
    static let tvOS = ServicesOptions(rawValue: 1 << 1)
    static let officialBuilds = ServicesOptions(rawValue: 1 << 2)
    static let unofficialBuilds = ServicesOptions(rawValue: 1 << 3)
    static let debugBuilds = ServicesOptions(rawValue: 1 << 4)
    static let releaseBuilds = ServicesOptions(rawValue: 1 << 5)

    static let all: ServicesOptions = [.iOS, .tvOS, .officialBuilds, .unofficialBuilds, .debugBuilds, .releaseBuilds]

    static let hockeyAppOnly: ServicesOptions = all.subtracting([.unofficialBuilds, .debugBuilds])
    static let iOSOnly: ServicesOptions = all.subtracting(.tvOS)

    static var isOfficialBuild: Bool = Bundle.main.bundleIdentifier!.contains("com.provenance-emu.provenance")
}

enum ServicePlatforms {
    case iOS
    case tvOS
}

protocol Service {
    var title: String { get }
    var description: String { get }

    var supportsCurrentConfiguration: Bool { get }
    var supportedConfigurations: ServicesOptions { get }
    func start() // -> Promise<Bool>
}

extension Service {
    var supportsCurrentConfiguration: Bool {
        #if os(tvOS)
            if !supportedConfigurations.contains(.tvOS) {
                return false
            }
        #elseif os(iOS)
            if !supportedConfigurations.contains(.iOS) {
                return false
            }
        #endif

        let official = ServicesOptions.isOfficialBuild
        guard !(official && !supportedConfigurations.contains(.officialBuilds)) else { return false }
        guard !(!official && !supportedConfigurations.contains(.unofficialBuilds)) else { return false }

        #if DEBUG
            let debug = true
            let release = false
        #else
            let debug = false
            let release = true
        #endif

        guard !(debug && !supportedConfigurations.contains(.debugBuilds)) else { return false }
        guard !(release && !supportedConfigurations.contains(.releaseBuilds)) else { return false }

        return true
    }
}
