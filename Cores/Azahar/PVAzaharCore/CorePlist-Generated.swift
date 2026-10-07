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
  public static let pvCopyright: String = "Copyright © 2014-2026 Citra Emulator Project / Azahar Emulator Project"
  public static let pvCoreIdentifier: String = "com.provenance.core.azahar"
  public static let pvjitRequirement: String = "optional"
  public static let pvLicenseName: String = "GPL-2.0-or-later"
  public static let pvLicenseURL: String = "https://github.com/azahar-emu/azahar/blob/HEAD/license.txt"
  public static let pvPrincipleClass: String = "PVAzahar.PVAzaharCore"
  public static let pvProjectName: String = "Azahar"
  public static let pvProjectURL: String = "https://azahar-emu.org"
  public static let pvProjectVersion: String = "2126.1.2+provenance"
  public static let pvSupportedSystems: [String] = ["com.provenance.3ds"]

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
