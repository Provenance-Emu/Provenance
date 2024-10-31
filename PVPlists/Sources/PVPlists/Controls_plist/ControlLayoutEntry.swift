//
//  ControlLayoutEntry.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation

public struct ControlLayoutEntry: Codable, Equatable, Hashable, Comparable {
    public static func < (lhs: ControlLayoutEntry, rhs: ControlLayoutEntry) -> Bool {
        if lhs.PVControlType < rhs.PVControlType {
            return true
        } else if lhs.PVControlType == rhs.PVControlType {
            if lhs.PVControlTitle == nil {
                return false
            }

            return lhs.PVControlTitle! < rhs.PVControlTitle!
        } else {
            return false
        }
    }

    public let PVControlType: String
    public let PVControlSize: String
    public let PVControlTitle: String?
    public let PVControlTint: String?
    public let PVGroupedButtons: [ControlGroupButton]?

    private enum CodingKeys: String, CodingKey {
        case PVControlType
        case PVControlSize
        case PVControlTitle
        case PVControlTint
        case PVGroupedButtons
    }
}

public extension ControlLayoutEntry {
    var dictionaryValue: [String: Any] {
        do {
            let data = try JSONEncoder().encode(self)
            let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            return dictionary!
        } catch {
            fatalError("Bad serialized data")
        }
    }
}
