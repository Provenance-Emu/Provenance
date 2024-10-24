//
//  GBPalette.swift
//  PVGambatte
//
//  Created by Joseph Mattiello on 10/9/24.
//

@objc public enum GBPalette: Int {
    case peaSoupGreen
    case pocket
    case blue
    case darkBlue
    case green
    case darkGreen
    case brown
    case darkBrown
    case red
    case yellow
    case orange
    case pastelMix
    case inverted
    case romTitle
    case grayscale
    
    public static var `default`: GBPalette { .peaSoupGreen }
}

extension GBPalette: CaseIterable { }
