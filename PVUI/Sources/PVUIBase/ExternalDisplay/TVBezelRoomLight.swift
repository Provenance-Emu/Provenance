//
//  TVBezelRoomLight.swift
//  PVUI
//
//  Whether the picture lights the room around a TV.
//

#if os(iOS) || os(tvOS)
import Defaults
import Metal
import PVSettings

/// The room-light setting, which goes by the device until the player sets it.
enum TVBezelRoomLight {

    /// Apple GPU family 7 and later (A14, M1). The room-light preset runs its ambient passes at
    /// the tube's size and costs several times the plain preset.
    static let gpuIsRecent: Bool = MTLCreateSystemDefaultDevice()?.supportsFamily(.apple7) ?? false

    static var isOn: Bool {
        ExternalDisplayBezelRules.lightsRoom(stored: Defaults[.externalDisplayBezelLightsRoom], gpuIsRecent: gpuIsRecent)
    }

    static func set(_ isOn: Bool) {
        Defaults[.externalDisplayBezelLightsRoom] = isOn
    }
}
#endif
