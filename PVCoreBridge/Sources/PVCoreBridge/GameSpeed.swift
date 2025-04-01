//
//  GameSpeed.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 9/20/24.
//


@objc public enum GameSpeed: Int, CaseIterable, CustomStringConvertible {
    case verySlow
    case slow
    case normal
    case fast
    case veryFast
    
    public var multiplier: Float {
        switch self {
        case .verySlow: return 0.25
        case .slow: return 0.5
        case .normal: return 1
        case .fast: return 2
        case .veryFast: return 5
        }
    }
    
    public var description: String {
        switch self {
        case .verySlow: return "Very Slow"
        case .slow: return "Slow"
        case .normal: return "Normal"
        case .fast: return "Fast"
        case .veryFast: return "Very Fast"
        }
    }
}
