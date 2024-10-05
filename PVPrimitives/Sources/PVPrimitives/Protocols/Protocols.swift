//
//  Protocols.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/20/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

@objc public enum VGRegion: Int, CaseIterable, Sendable {
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
            if #available(iOS 16, macOS 13, *) {
                return Locale.current.region?.identifier != "CN"
            } else {
                // Fallback on earlier versions
                return Locale.current.identifier != "CN"
            }
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

    public static let allCountries: Set<VGRegion> = {
        Set(VGRegion.allCases.filter { c in c.isCountry })
    }()
}

public struct RegionOptions: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: Int64

    public init(rawValue: Int64) {
        self.rawValue = rawValue
    }

    public static let asia = RegionOptions(rawValue: 1 << VGRegion.asia.rawValue)
    public static let australia = RegionOptions(rawValue: 1 << VGRegion.australia.rawValue)
    public static let brazil = RegionOptions(rawValue: 1 << VGRegion.brazil.rawValue)
    public static let canada = RegionOptions(rawValue: 1 << VGRegion.canada.rawValue)
    public static let china = RegionOptions(rawValue: 1 << VGRegion.china.rawValue)
    public static let denmark = RegionOptions(rawValue: 1 << VGRegion.denmark.rawValue)
    public static let europe = RegionOptions(rawValue: 1 << VGRegion.europe.rawValue)
    public static let finland = RegionOptions(rawValue: 1 << VGRegion.finland.rawValue)
    public static let france = RegionOptions(rawValue: 1 << VGRegion.france.rawValue)
    public static let germany = RegionOptions(rawValue: 1 << VGRegion.germany.rawValue)
    public static let hongKong = RegionOptions(rawValue: 1 << VGRegion.hongKong.rawValue)
    public static let italy = RegionOptions(rawValue: 1 << VGRegion.italy.rawValue)
    public static let japan = RegionOptions(rawValue: 1 << VGRegion.japan.rawValue)
    public static let korea = RegionOptions(rawValue: 1 << VGRegion.korea.rawValue)
    public static let netherlands = RegionOptions(rawValue: 1 << VGRegion.netherlands.rawValue)
    public static let russia = RegionOptions(rawValue: 1 << VGRegion.russia.rawValue)
    public static let spain = RegionOptions(rawValue: 1 << VGRegion.spain.rawValue)
    public static let sweden = RegionOptions(rawValue: 1 << VGRegion.sweden.rawValue)
    public static let taiwan = RegionOptions(rawValue: 1 << VGRegion.taiwan.rawValue)
    public static let unknown = RegionOptions(rawValue: 1 << VGRegion.unknown.rawValue)
    public static let usa = RegionOptions(rawValue: 1 << VGRegion.usa.rawValue)
    public static let world = RegionOptions(rawValue: 1 << VGRegion.world.rawValue)
    //	public static let asiaAndAustralia    = RegionOptions(rawValue: 1 << VGRegion.asiaAndAustralia.rawValue)
    //	public static let brazilAndKorea    = RegionOptions(rawValue: 1 << VGRegion.brazilAndKorea.rawValue)
    //	public static let japanAndEurope    = RegionOptions(rawValue: 1 << VGRegion.japanAndKorea.rawValue)
    //	public static let japanAndKorea    = RegionOptions(rawValue: 1 << VGRegion.japanAndKorea.rawValue)
    //	public static let japanAndUSA    = RegionOptions(rawValue: 1 << VGRegion.japanAndUSA.rawValue)
    //	public static let usaAndAustralia    = RegionOptions(rawValue: 1 << VGRegion.usaAndAustralia.rawValue)
    //	public static let usaAndEurope    = RegionOptions(rawValue: 1 << VGRegion.usaAndEurope.rawValue)
    //	public static let usaAndKorea    = RegionOptions(rawValue: 1 << VGRegion.usaAndKorea.rawValue)
    //	public static let europeAndAustralia    = RegionOptions(rawValue: 1 << VGRegion.EuropeAndAustralia.rawValue)
    public static let greece = RegionOptions(rawValue: 1 << VGRegion.greece.rawValue)
    public static let ireland = RegionOptions(rawValue: 1 << VGRegion.ireland.rawValue)
    public static let norway = RegionOptions(rawValue: 1 << VGRegion.norway.rawValue)
    public static let portugal = RegionOptions(rawValue: 1 << VGRegion.portugal.rawValue)
    public static let scandinavia = RegionOptions(rawValue: 1 << VGRegion.scandinavia.rawValue)
    public static let uk = RegionOptions(rawValue: 1 << VGRegion.uk.rawValue)
    //	public static let usaAndBrazil    = RegionOptions(rawValue: 1 << VGRegion.usaAndAustralia.rawValue)
    public static let poland = RegionOptions(rawValue: 1 << VGRegion.poland.rawValue)

    public static let allCountries: RegionOptions = {
        RegionOptions(regions: VGRegion.allCountries)
    }()

    public static let all: RegionOptions = {
        RegionOptions(regions: VGRegion.allCases)
    }()
}

public extension RegionOptions {
    init<C: Collection>(regions: C) where C.Iterator.Element == VGRegion {
        let allBits = regions.reduce(Int64(0), { $0 & 1 << $1.rawValue })
        self = RegionOptions(rawValue: allBits)
    }

    init(region: VGRegion) {
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
