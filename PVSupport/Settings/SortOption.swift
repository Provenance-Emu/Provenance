//
//  SortOption.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 11/24/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

@objc
public enum SortOptions: UInt, CustomStringConvertible, CaseIterable, UserDefaultsRepresentable {
    case title
    case importDate
    case lastPlayed

    public var description: String {
        switch self {
        case .title: return "Title"
        case .importDate: return "Imported"
        case .lastPlayed: return "Last Played"
        }
    }

    public var row: UInt {
        return rawValue
    }

    public static var count: Int {
        return allCases.count
    }

    public static func optionForRow(_ row: UInt) -> SortOptions {
        switch row {
        case 0:
            return .title
        case 1:
            return .importDate
        case 2:
            return .lastPlayed
        default:
            ELOG("Bad row \(row)")
            return .title
        }
    }
}
