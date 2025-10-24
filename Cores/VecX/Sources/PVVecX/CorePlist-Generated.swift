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
  public static let pvCoreIdentifier: String = "com.provenance.core.VecX"
  public static let pvPrincipleClass: String = "PVVecX.PVVecXCore"
  public static let pvProjectName: String = "VecX"
  public static let pvProjectURL: String = "https://github.com/libretro/libretro-vecx"
  public static let pvProjectVersion: String = "a4ae282"
  public static let pvSupportedSystems: [String] = ["com.provenance.vectrex"]
  public static let pvDisabled: Bool = true

  #if canImport(PVCoreBridge)
    public static var corePlist: EmulatorCoreInfoPlist {
        .init(
            identifier: CorePlist.pvCoreIdentifier,
            principleClass: CorePlist.pvPrincipleClass,
            supportedSystems: CorePlist.pvSupportedSystems,
            projectName: CorePlist.pvProjectName,
            projectURL: CorePlist.pvProjectURL,
            projectVersion: CorePlist.pvProjectVersion,
            disabled: CorePlist.pvDisabled
        )
    }

    public var corePlist: EmulatorCoreInfoPlist { Self.corePlist }
  #endif
}
// swiftlint:enable identifier_name line_length number_separator type_body_length
