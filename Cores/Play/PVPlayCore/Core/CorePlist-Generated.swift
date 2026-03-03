// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

#if canImport(PVCoreBridge)
@_exported import PVCoreBridge
@_exported import PVPlists
#endif

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

// MARK: - Plist Files

// swiftlint:disable identifier_name line_length number_separator type_body_length
public enum CorePlist {
  public static let pvCoreIdentifier: String = "com.provenance.core.play"
  public static let pvPrincipleClass: String = "PVPlay.PVPlayCore"
  public static let pvProjectName: String = "Play!"
  public static let pvProjectURL: String = "https://github.com/jpd002/Play-"
  public static let pvProjectVersion: String = "0.58"
  public static let pvSupportedSystems: [String] = ["com.provenance.ps2"]
  public static let pvSupportedCheatTypes: [String] = ["Code Breaker", "Game Shark V3", "Pro Action Replay V1", "Pro Action Replay V2", "Raw MemAddress:Value Pairs"]

  #if canImport(PVCoreBridge)
    public static var corePlist: EmulatorCoreInfoPlist {
        .init(
            identifier: CorePlist.pvCoreIdentifier,
            principleClass: CorePlist.pvPrincipleClass,
            supportedSystems: CorePlist.pvSupportedSystems,
            projectName: CorePlist.pvProjectName,
            projectURL: CorePlist.pvProjectURL,
            projectVersion: CorePlist.pvProjectVersion,
            supportedCheatTypes: CorePlist.pvSupportedCheatTypes.compactMap { CheatCodeTypes(string: $0) })
    }

    public var corePlist: EmulatorCoreInfoPlist { Self.corePlist }
  #endif
}
// swiftlint:enable identifier_name line_length number_separator type_body_length
