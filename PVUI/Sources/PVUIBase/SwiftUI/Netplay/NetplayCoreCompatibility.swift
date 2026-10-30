import Foundation
import PVNetplay
import PVSystems

/// Explicit capabilities of Provenance's netplay integrations, never inferred from console support.
enum NetplayCoreCompatibility {
    static func support(coreIdentifier: String, systemIdentifier: String, coreVersion: String = "") -> NetplayCoreSupport? {
        guard let system = SystemIdentifier(rawValue: systemIdentifier) else { return nil }
        switch (coreIdentifier, system) {
        case ("com.provenance.core.dolphin", .GameCube), ("com.provenance.core.dolphin", .Wii):
            return NetplayCoreSupport(coreIdentifier: coreIdentifier, modes: [.sharedConsole, .alternating], maxPlayers: 4,
                                      supportsSpectators: true, supportsFrameDelay: true, coreVersion: coreVersion)
        case ("com.provenance.core.mGBA", .GBA):
            // The native bridge currently implements two peers, not a four-device cable.
            return NetplayCoreSupport(coreIdentifier: coreIdentifier, modes: [.linkCable], maxPlayers: 2, coreVersion: coreVersion)
        case ("com.provenance.core.ppsspp", .PSP), ("ppsspp.libretro.framework", .PSP):
            return NetplayCoreSupport(coreIdentifier: coreIdentifier, modes: [.localWireless], maxPlayers: 4, coreVersion: coreVersion)
        case ("com.provenance.core.mednafen", .NES), ("com.provenance.core.mednafen", .FDS),
             ("com.provenance.core.mednafen", .SNES), ("com.provenance.core.mednafen", .PSX),
             ("com.provenance.core.mednafen", .Saturn), ("com.provenance.core.mednafen", .PCE),
             ("com.provenance.core.mednafen", .PCECD), ("com.provenance.core.mednafen", .SGFX),
             ("com.provenance.core.mednafen", .PCFX):
            return NetplayCoreSupport(coreIdentifier: coreIdentifier, modes: [.sharedConsole, .alternating], maxPlayers: 4,
                                      supportsSpectators: true, coreVersion: coreVersion)
        default:
            // Other thin cores must register env 78 at runtime. A bundled dylib or
            // a historical RetroArch netplay flag doesn't establish this capability.
            guard let mode = netpacketMode(coreIdentifier: coreIdentifier, systemIdentifier: systemIdentifier),
                  UserDefaults.standard.bool(forKey: observationKey(coreIdentifier, coreVersion)) else { return nil }
            return NetplayCoreSupport(coreIdentifier: coreIdentifier, modes: [mode], maxPlayers: 2, coreVersion: coreVersion)
        }
    }

    /// These cores must demonstrate env 78 in this build before the library recommends them.
    static func netpacketMode(coreIdentifier: String, systemIdentifier: String) -> NetplayPlayMode? {
        switch (coreIdentifier, SystemIdentifier(rawValue: systemIdentifier)) {
        case ("gpsp.libretro.framework", .GBA): return .linkCable
        case ("melondsds.libretro.framework", .DS): return .localWireless
        default: return nil
        }
    }

    static func recordNetpacket(coreIdentifier: String, coreVersion: String, available: Bool) {
        UserDefaults.standard.set(available, forKey: observationKey(coreIdentifier, coreVersion))
    }

    private static func observationKey(_ identifier: String, _ version: String) -> String {
        #if os(tvOS)
        let platform = "tvos"
        #else
        let platform = "ios"
        #endif
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "development"
        return "netplay.env78.\(platform).\(build).\(identifier).\(version)"
    }
}
