//
//  ScreenType.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 10/23/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

@objc
public enum ScreenTypeObjC: UInt, CaseIterable, Codable {
    case unknown
    case monochromaticLCD
    case colorLCD
    case crt
    case modern
    case dotMatrix

    public
    var isLCD: Bool {
        switch self {
        case .monochromaticLCD, .colorLCD: return true
        default: return false
        }
    }

    public
    var isCRT: Bool {
        return self == .crt
    }

    public
    var isMonoChromatic: Bool {
        switch self {
        case .monochromaticLCD, .dotMatrix: return true
        default: return false
        }
    }

    public init(screenType: ScreenType) {
        switch screenType {
        case .unknown: self = .unknown
        case .monochromaticLCD: self = .monochromaticLCD
        case .colorLCD: self = .colorLCD
        case .crt: self = .crt
        case .modern: self = .modern
        case .dotMatrix: self = .dotMatrix
        }
    }
    
    public var stringValue: String {
        switch self {
        case .unknown: return ""
        case .monochromaticLCD: return "MonoLCD"
        case .colorLCD: return "ColorLCD"
        case .crt: return "CRT"
        case .modern: return "Modern"
        case .dotMatrix: return "DotMatrix"
        }
    }
}

public enum ScreenType: String, CaseIterable, Codable {
    case unknown = ""
    case monochromaticLCD = "MonoLCD"
    case colorLCD = "ColorLCD"
    case crt = "CRT"
    case modern = "Modern"
    case dotMatrix = "DotMatrix"

    public
    var isLCD: Bool {
        switch self {
        case .monochromaticLCD, .colorLCD: return true
        default: return false
        }
    }

    public
    var isCRT: Bool {
        return self == .crt
    }

    public
    var isMonoChromatic: Bool {
        switch self {
        case .monochromaticLCD, .dotMatrix: return true
        default: return false
        }
    }

    public
    var objcType: ScreenTypeObjC {
        return .init(screenType: self)
    }

    public init(screenType: ScreenTypeObjC) {
        switch screenType {
        case .unknown: self = .unknown
        case .monochromaticLCD: self = .monochromaticLCD
        case .colorLCD: self = .colorLCD
        case .crt: self = .crt
        case .modern: self = .modern
        case .dotMatrix: self = .dotMatrix
        }
    }
}
