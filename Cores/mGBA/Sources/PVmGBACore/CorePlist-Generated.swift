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
  public static let pvCoreIdentifier: String = "com.provenance.core.mGBA"
  public static let pvPrincipleClass: String = "PVmGBACore.PVmGBACore"
  public static let pvProjectName: String = "mGBA"
  public static let pvProjectURL: String = "https://mgba.io/"
  public static let pvProjectVersion: String = "0.10.3"
  public static let pvSupportedSystems: [String] = ["com.provenance.gba"]
  public static let pvSupportedCheatTypes: [String] = ["Game Shark", "Code Breaker", "Pro Action Replay"]

  #if canImport(PVCoreBridge)
    public static var corePlist: EmulatorCoreInfoPlist {
        .init(
            identifier: CorePlist.pvCoreIdentifier,
            principleClass: CorePlist.pvPrincipleClass,
            supportedSystems: CorePlist.pvSupportedSystems,
            projectName: CorePlist.pvProjectName,
            projectURL: CorePlist.pvProjectURL,
            projectVersion: CorePlist.pvProjectVersion
        )
    }

    public var corePlist: EmulatorCoreInfoPlist { Self.corePlist }
  #endif
}
// swiftlint:enable identifier_name line_length number_separator type_body_length
