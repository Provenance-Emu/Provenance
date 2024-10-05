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
  public static let pvCoreIdentifier: String = "com.provenance.core.genplusgx"
  public static let pvPrincipleClass: String = "PVGenesis.PVCoreGenesisPlus"
  public static let pvProjectName: String = "Genesis Plus GX"
  public static let pvProjectURL: String = "https://github.com/ekeeke/Genesis-Plus-GX"
  public static let pvProjectVersion: String = "1.7.4 12.13.2020"
  public static let pvSupportedSystems: [String] = ["com.provenance.genesis", "com.provenance.gamegear", "com.provenance.mastersystem", "com.provenance.sg1000", "com.provenance.segacd"]

  #if canImport(PVCoreBridge)
    public static var corePlist: EmulatorCoreInfoPlist {
        .init(
            identifier: CorePlist.pvCoreIdentifier,
            principleClass: CorePlist.pvPrincipleClass,
            supportedSystems: CorePlist.pvSupportedSystems,
            projectName: CorePlist.pvProjectName,
            projectURL: CorePlist.pvProjectURL,
            projectVersion: CorePlist.pvProjectVersion)
    }

    public var corePlist: EmulatorCoreInfoPlist { Self.corePlist }
  #endif
}
// swiftlint:enable identifier_name line_length number_separator type_body_length
