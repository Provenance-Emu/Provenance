// SystemRegionPreference.swift
// PVSettings
//
// User-selectable region for region-aware emulator cores.

import Foundation
import Defaults

/// Preferred console region for region-aware cores (currently Sega Saturn via
/// the thin libretro wrapper). `.auto` lets the core auto-detect from the disc
/// header; the explicit cases force a region so multi-region games run in the
/// chosen locale instead of defaulting to Japan.
///
/// The raw values are deliberately neutral; each core mapping translates them to
/// that core's own option strings (e.g. `beetle_saturn_region`).
public enum SystemRegionPreference: String, Codable, Equatable, Hashable,
    UserDefaultsRepresentable, Defaults.Serializable, CaseIterable, Sendable {

    case auto
    case japan
    case northAmerica
    case europe

    public var displayName: String {
        switch self {
        case .auto:         return "Auto Detect"
        case .japan:        return "Japan (NTSC-J)"
        case .northAmerica: return "North America (NTSC-U)"
        case .europe:       return "Europe (PAL)"
        }
    }

    public var symbolName: String {
        switch self {
        case .auto:         return "globe"
        case .japan:        return "globe.asia.australia"
        case .northAmerica: return "globe.americas"
        case .europe:       return "globe.europe.africa"
        }
    }

    /// Value for Beetle Saturn's `beetle_saturn_region` core option.
    /// Strings must match the core's option list exactly (verified against
    /// libretro/beetle-saturn-libretro `libretro_core_options.h`).
    public var beetleSaturnRegionValue: String {
        switch self {
        case .auto:         return "Auto Detect"
        case .japan:        return "Japan"
        case .northAmerica: return "North America"
        case .europe:       return "Europe"
        }
    }
}
