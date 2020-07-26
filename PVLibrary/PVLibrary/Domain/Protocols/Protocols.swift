//
//  Protocols.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/20/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

@objc
public enum VGRegion: Int, CaseIterable {
    case asia = 1
    case australia
    case brazil
    case canada
    case china
    case denmark
    case europe
    case finland
    case france
    case germany
    case hongKong
    case italy
    case japan
    case korea
    case netherlands
    case russia
    case spain
    case sweden
    case taiwan
    case unknown
    case usa
    case world
    case asiaAndAustralia
    case brazilAndKorea
    case japanAndEurope
    case japanAndKorea
    case japanAndUSA
    case usaAndAustralia
    case usaAndEurope
    case usaAndKorea
    case europeAndAustralia
    case greece
    case ireland
    case norway
    case portugal
    case scandinavia
    case uk
    case usaAndBrazil
    case poland

    public var isCountry: Bool {
        switch self {
        case .taiwan:
            // Note: Revert this when China recognizes Taiwan
            return Locale.current.regionCode != "CN"
        case .asia,
             .unknown,
             .world,
             .asiaAndAustralia,
             .brazilAndKorea,
             .japanAndEurope, .japanAndKorea, .japanAndUSA,
             .usaAndAustralia, .usaAndEurope, .usaAndKorea,
             .europeAndAustralia,
             .scandinavia,
             .usaAndBrazil:
            return false
        default:
            return true
        }
    }

    static let allCountries: Set<VGRegion> = {
        Set(VGRegion.allCases.filter { c in c.isCountry })
    }()
}

public struct RegionOptions: OptionSet, Codable, Equatable {
    public let rawValue: Int64

    public init(rawValue: Int64) {
        self.rawValue = rawValue
    }

    static let asia = RegionOptions(rawValue: 1 << VGRegion.asia.rawValue)
    static let australia = RegionOptions(rawValue: 1 << VGRegion.australia.rawValue)
    static let brazil = RegionOptions(rawValue: 1 << VGRegion.brazil.rawValue)
    static let canada = RegionOptions(rawValue: 1 << VGRegion.canada.rawValue)
    static let china = RegionOptions(rawValue: 1 << VGRegion.china.rawValue)
    static let denmark = RegionOptions(rawValue: 1 << VGRegion.denmark.rawValue)
    static let europe = RegionOptions(rawValue: 1 << VGRegion.europe.rawValue)
    static let finland = RegionOptions(rawValue: 1 << VGRegion.finland.rawValue)
    static let france = RegionOptions(rawValue: 1 << VGRegion.france.rawValue)
    static let germany = RegionOptions(rawValue: 1 << VGRegion.germany.rawValue)
    static let hongKong = RegionOptions(rawValue: 1 << VGRegion.hongKong.rawValue)
    static let italy = RegionOptions(rawValue: 1 << VGRegion.italy.rawValue)
    static let japan = RegionOptions(rawValue: 1 << VGRegion.japan.rawValue)
    static let korea = RegionOptions(rawValue: 1 << VGRegion.korea.rawValue)
    static let netherlands = RegionOptions(rawValue: 1 << VGRegion.netherlands.rawValue)
    static let russia = RegionOptions(rawValue: 1 << VGRegion.russia.rawValue)
    static let spain = RegionOptions(rawValue: 1 << VGRegion.spain.rawValue)
    static let sweden = RegionOptions(rawValue: 1 << VGRegion.sweden.rawValue)
    static let taiwan = RegionOptions(rawValue: 1 << VGRegion.taiwan.rawValue)
    static let unknown = RegionOptions(rawValue: 1 << VGRegion.unknown.rawValue)
    static let usa = RegionOptions(rawValue: 1 << VGRegion.usa.rawValue)
    static let world = RegionOptions(rawValue: 1 << VGRegion.world.rawValue)
    //	static let asiaAndAustralia    = RegionOptions(rawValue: 1 << VGRegion.asiaAndAustralia.rawValue)
    //	static let brazilAndKorea    = RegionOptions(rawValue: 1 << VGRegion.brazilAndKorea.rawValue)
    //	static let japanAndEurope    = RegionOptions(rawValue: 1 << VGRegion.japanAndKorea.rawValue)
    //	static let japanAndKorea    = RegionOptions(rawValue: 1 << VGRegion.japanAndKorea.rawValue)
    //	static let japanAndUSA    = RegionOptions(rawValue: 1 << VGRegion.japanAndUSA.rawValue)
    //	static let usaAndAustralia    = RegionOptions(rawValue: 1 << VGRegion.usaAndAustralia.rawValue)
    //	static let usaAndEurope    = RegionOptions(rawValue: 1 << VGRegion.usaAndEurope.rawValue)
    //	static let usaAndKorea    = RegionOptions(rawValue: 1 << VGRegion.usaAndKorea.rawValue)
    //	static let europeAndAustralia    = RegionOptions(rawValue: 1 << VGRegion.EuropeAndAustralia.rawValue)
    static let greece = RegionOptions(rawValue: 1 << VGRegion.greece.rawValue)
    static let ireland = RegionOptions(rawValue: 1 << VGRegion.ireland.rawValue)
    static let norway = RegionOptions(rawValue: 1 << VGRegion.norway.rawValue)
    static let portugal = RegionOptions(rawValue: 1 << VGRegion.portugal.rawValue)
    static let scandinavia = RegionOptions(rawValue: 1 << VGRegion.scandinavia.rawValue)
    static let uk = RegionOptions(rawValue: 1 << VGRegion.uk.rawValue)
    //	static let usaAndBrazil    = RegionOptions(rawValue: 1 << VGRegion.usaAndAustralia.rawValue)
    static let poland = RegionOptions(rawValue: 1 << VGRegion.poland.rawValue)

    static let allCountries: RegionOptions = {
        RegionOptions(regions: VGRegion.allCountries)
    }()

    static let all: RegionOptions = {
        RegionOptions(regions: VGRegion.allCases)
    }()
}

extension RegionOptions {
    public init<C: Collection>(regions: C) where C.Iterator.Element == VGRegion {
        let allBits = regions.reduce(Int64(0), { $0 & 1 << $1.rawValue })
        self = RegionOptions(rawValue: allBits)
    }

    public init(region: VGRegion) {
        switch region {
        case .asia, .australia, .brazil, .canada, .china, .denmark, .europe, .finland, .france, .germany, .hongKong,
             .italy, .japan, .korea, .netherlands, .russia, .spain, .sweden, .taiwan, .unknown, .usa, .world, .greece,
             .ireland, .norway, .portugal, .scandinavia, .uk, .poland:
            self.init(rawValue: 1 << region.rawValue)
        case .asiaAndAustralia:
            self = [.asia, .australia]
        case .brazilAndKorea:
            self = [.brazil, .korea]
        case .japanAndEurope:
            self = [.japan, .europe]
        case .japanAndKorea:
            self = [.japan, .korea]
        case .japanAndUSA:
            self = [.japan, .usa]
        case .usaAndAustralia:
            self = [.usa, .australia]
        case .usaAndEurope:
            self = [.usa, .europe]
        case .usaAndKorea:
            self = [.usa, .korea]
        case .europeAndAustralia:
            self = [.europe, .australia]
        case .usaAndBrazil:
            self = [.usa, .brazil]
        }
    }
}

public protocol Regioned {
    var regions: RegionOptions { get }
}
