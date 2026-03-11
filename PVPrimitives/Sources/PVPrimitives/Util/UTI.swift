//
//  UTI.swift
//  fseventstool
//
//  Created by Matthias Keiser on 09.01.17.
//  Copyright © 2017 Tristan Inc. All rights reserved.
//

import Foundation
#if canImport(CoreServices)
import CoreServices
#endif

public extension UTI {
    // General ROM types
    nonisolated(unsafe) static let rom = UTI(rawValue: "com.provenance.rom")
    nonisolated(unsafe) static let bios = UTI(rawValue: "com.provenance.bios")
    nonisolated(unsafe) static let cheat = UTI(rawValue: "com.provenance.cheat")
    nonisolated(unsafe) static let artwork = UTI(rawValue: "com.provenance.artwork")
    nonisolated(unsafe) static let savestate = UTI(rawValue: "com.provenance.savestate")
    nonisolated(unsafe) static let sevenZipArchive = UTI(rawValue: "org.7-zip.7-zip-archive")
    nonisolated(unsafe) static let rar = UTI(rawValue: "com.rarlab.rar-archive")

    // Console-specific ROM types
    nonisolated(unsafe) static let nes = UTI(rawValue: "com.provenance.rom.nes")
    nonisolated(unsafe) static let fds = UTI(rawValue: "com.provenance.rom.fds")
    nonisolated(unsafe) static let snes = UTI(rawValue: "com.provenance.rom.snes")
    nonisolated(unsafe) static let gb = UTI(rawValue: "com.provenance.rom.gb")
    nonisolated(unsafe) static let gbc = UTI(rawValue: "com.provenance.rom.gbc")
    nonisolated(unsafe) static let gba = UTI(rawValue: "com.provenance.rom.gba")
    nonisolated(unsafe) static let genesis = UTI(rawValue: "com.provenance.rom.genesis")
    nonisolated(unsafe) static let masterSystem = UTI(rawValue: "com.provenance.rom.mastersystem")
    nonisolated(unsafe) static let gameGear = UTI(rawValue: "com.provenance.rom.gamegear")
    nonisolated(unsafe) static let n64 = UTI(rawValue: "com.provenance.rom.n64")
    nonisolated(unsafe) static let ds = UTI(rawValue: "com.provenance.rom.ds")
    nonisolated(unsafe) static let threeDO = UTI(rawValue: "com.provenance.rom.3do")
    nonisolated(unsafe) static let jaguar = UTI(rawValue: "com.provenance.rom.jaguar")
    nonisolated(unsafe) static let jaguarCD = UTI(rawValue: "com.provenance.rom.jaguarcd")
    nonisolated(unsafe) static let atarist = UTI(rawValue: "com.provenance.rom.atarist")
    nonisolated(unsafe) static let atari8bit = UTI(rawValue: "com.provenance.rom.atari8bit")
    nonisolated(unsafe) static let c64 = UTI(rawValue: "com.provenance.rom.c64")
    nonisolated(unsafe) static let cdi = UTI(rawValue: "com.provenance.rom.cdi")
    nonisolated(unsafe) static let cps1 = UTI(rawValue: "com.provenance.rom.cps1")
    nonisolated(unsafe) static let cps2 = UTI(rawValue: "com.provenance.rom.cps2")
    nonisolated(unsafe) static let cps3 = UTI(rawValue: "com.provenance.rom.cps3")
    nonisolated(unsafe) static let doom = UTI(rawValue: "com.provenance.rom.doom")
    nonisolated(unsafe) static let gamecube = UTI(rawValue: "com.provenance.rom.gamecube")
    nonisolated(unsafe) static let neogeo = UTI(rawValue: "com.provenance.rom.neogeo")
    nonisolated(unsafe) static let palmos = UTI(rawValue: "com.provenance.rom.palmos")
    nonisolated(unsafe) static let pc98 = UTI(rawValue: "com.provenance.rom.pc98")
    nonisolated(unsafe) static let psp = UTI(rawValue: "com.provenance.rom.psp")
    nonisolated(unsafe) static let quake = UTI(rawValue: "com.provenance.rom.quake")
    nonisolated(unsafe) static let quake2 = UTI(rawValue: "com.provenance.rom.quake2")
    nonisolated(unsafe) static let wolf3d = UTI(rawValue: "com.provenance.rom.wolf3d")
    nonisolated(unsafe) static let ws = UTI(rawValue: "com.provenance.rom.ws")
    nonisolated(unsafe) static let wsc = UTI(rawValue: "com.provenance.rom.wsc")
    nonisolated(unsafe) static let zxspectrum = UTI(rawValue: "com.provenance.rom.zxspectrum")
    nonisolated(unsafe) static let segacd = UTI(rawValue: "com.provenance.rom.segacd")
    nonisolated(unsafe) static let sg1000 = UTI(rawValue: "com.provenance.rom.sg1000")
    nonisolated(unsafe) static let sgfx = UTI(rawValue: "com.provenance.rom.sgfx")
    nonisolated(unsafe) static let supervision = UTI(rawValue: "com.provenance.rom.supervision")
    nonisolated(unsafe) static let tic80 = UTI(rawValue: "com.provenance.rom.tic80")
    nonisolated(unsafe) static let vectrex = UTI(rawValue: "com.provenance.rom.vectrex")
    nonisolated(unsafe) static let vb = UTI(rawValue: "com.provenance.rom.vb")
    nonisolated(unsafe) static let wii = UTI(rawValue: "com.provenance.rom.wii")
    nonisolated(unsafe) static let threeDS = UTI(rawValue: "com.provenance.rom.3ds")
    nonisolated(unsafe) static let appleII = UTI(rawValue: "com.provenance.rom.appleii")
    nonisolated(unsafe) static let atari2600 = UTI(rawValue: "com.provenance.rom.atari2600")
    nonisolated(unsafe) static let atari5200 = UTI(rawValue: "com.provenance.rom.atari5200")
    nonisolated(unsafe) static let atari7800 = UTI(rawValue: "com.provenance.rom.atari7800")
    nonisolated(unsafe) static let atariLynx = UTI(rawValue: "com.provenance.rom.lynx")
    nonisolated(unsafe) static let colecovision = UTI(rawValue: "com.provenance.rom.colecovision")
    nonisolated(unsafe) static let dos = UTI(rawValue: "com.provenance.rom.dos")
    nonisolated(unsafe) static let dreamcast = UTI(rawValue: "com.provenance.rom.dreamcast")
    nonisolated(unsafe) static let ep128 = UTI(rawValue: "com.provenance.rom.ep128")
    nonisolated(unsafe) static let intellivision = UTI(rawValue: "com.provenance.rom.intellivision")
    nonisolated(unsafe) static let macintosh = UTI(rawValue: "com.provenance.rom.macintosh")
    nonisolated(unsafe) static let mame = UTI(rawValue: "com.provenance.rom.mame")
    nonisolated(unsafe) static let msx = UTI(rawValue: "com.provenance.rom.msx")
    nonisolated(unsafe) static let msx2 = UTI(rawValue: "com.provenance.rom.msx2")
    nonisolated(unsafe) static let music = UTI(rawValue: "com.provenance.rom.music")
    nonisolated(unsafe) static let ngp = UTI(rawValue: "com.provenance.rom.ngp")
    nonisolated(unsafe) static let ngpc = UTI(rawValue: "com.provenance.rom.ngpc")
    nonisolated(unsafe) static let odyssey2 = UTI(rawValue: "com.provenance.rom.odyssey2")
    nonisolated(unsafe) static let pce = UTI(rawValue: "com.provenance.rom.pce")
    nonisolated(unsafe) static let pcecd = UTI(rawValue: "com.provenance.rom.pcecd")
    nonisolated(unsafe) static let pcfx = UTI(rawValue: "com.provenance.rom.pcfx")
    nonisolated(unsafe) static let pokemonmini = UTI(rawValue: "com.provenance.rom.pokemonmini")
    nonisolated(unsafe) static let ps2 = UTI(rawValue: "com.provenance.rom.ps2")
    nonisolated(unsafe) static let ps3 = UTI(rawValue: "com.provenance.rom.ps3")
    nonisolated(unsafe) static let psx = UTI(rawValue: "com.provenance.rom.psx")
    nonisolated(unsafe) static let retroarch = UTI(rawValue: "com.provenance.rom.retroarch")
    nonisolated(unsafe) static let saturn = UTI(rawValue: "com.provenance.rom.saturn")
    nonisolated(unsafe) static let sega32x = UTI(rawValue: "com.provenance.rom.sega32x")
}

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers

// also declare the content type in the Info.plist (UTExportedTypeDeclarations)
@available(iOS 14.0, tvOS 14.0, *)
public extension UTType {
    // General ROM types — all exported (Provenance defines the format/type)
    static let rom: UTType = UTType(exportedAs: "com.provenance.rom", conformingTo: .data)
    static let bios: UTType = UTType(exportedAs: "com.provenance.bios", conformingTo: .rom)
    static let cheat: UTType = UTType(exportedAs: "com.provenance.cheat", conformingTo: .data)
    static let artwork: UTType = UTType(exportedAs: "com.provenance.artwork", conformingTo: .image)
    static let savestate: UTType = UTType(exportedAs: "com.provenance.savestate", conformingTo: .data)
    // Archive types — imported (owned by the archive format standards)
    static let sevenZipArchive: UTType = UTType(importedAs: "org.7-zip.7-zip-archive", conformingTo: .archive)
    static let rar: UTType = UTType(importedAs: "com.rarlab.rar-archive", conformingTo: .archive)

    // Console-specific ROM types — all exported (per-system, conform to .rom)
    static let appleII: UTType = UTType(exportedAs: "com.provenance.rom.appleii", conformingTo: .rom)
    static let atari2600: UTType = UTType(exportedAs: "com.provenance.rom.atari2600", conformingTo: .rom)
    static let atari5200: UTType = UTType(exportedAs: "com.provenance.rom.atari5200", conformingTo: .rom)
    static let atari7800: UTType = UTType(exportedAs: "com.provenance.rom.atari7800", conformingTo: .rom)
    static let atari8bit: UTType = UTType(exportedAs: "com.provenance.rom.atari8bit", conformingTo: .rom)
    static let atariLynx: UTType = UTType(exportedAs: "com.provenance.rom.lynx", conformingTo: .rom)
    static let atarist: UTType = UTType(exportedAs: "com.provenance.rom.atarist", conformingTo: .rom)
    static let c64: UTType = UTType(exportedAs: "com.provenance.rom.c64", conformingTo: .rom)
    static let cdi: UTType = UTType(exportedAs: "com.provenance.rom.cdi", conformingTo: .rom)
    static let colecovision: UTType = UTType(exportedAs: "com.provenance.rom.colecovision", conformingTo: .rom)
    static let cps1: UTType = UTType(exportedAs: "com.provenance.rom.cps1", conformingTo: .rom)
    static let cps2: UTType = UTType(exportedAs: "com.provenance.rom.cps2", conformingTo: .rom)
    static let cps3: UTType = UTType(exportedAs: "com.provenance.rom.cps3", conformingTo: .rom)
    static let doom: UTType = UTType(exportedAs: "com.provenance.rom.doom", conformingTo: .rom)
    static let dos: UTType = UTType(exportedAs: "com.provenance.rom.dos", conformingTo: .rom)
    static let dreamcast: UTType = UTType(exportedAs: "com.provenance.rom.dreamcast", conformingTo: .rom)
    static let ds: UTType = UTType(exportedAs: "com.provenance.rom.ds", conformingTo: .rom)
    static let ep128: UTType = UTType(exportedAs: "com.provenance.rom.ep128", conformingTo: .rom)
    static let fds: UTType = UTType(exportedAs: "com.provenance.rom.fds", conformingTo: .rom)
    static let gamecube: UTType = UTType(exportedAs: "com.provenance.rom.gamecube", conformingTo: .rom)
    static let gameGear: UTType = UTType(exportedAs: "com.provenance.rom.gamegear", conformingTo: .rom)
    static let gb: UTType = UTType(exportedAs: "com.provenance.rom.gb", conformingTo: .rom)
    static let gba: UTType = UTType(exportedAs: "com.provenance.rom.gba", conformingTo: .rom)
    static let gbc: UTType = UTType(exportedAs: "com.provenance.rom.gbc", conformingTo: .rom)
    static let genesis: UTType = UTType(exportedAs: "com.provenance.rom.genesis", conformingTo: .rom)
    static let intellivision: UTType = UTType(exportedAs: "com.provenance.rom.intellivision", conformingTo: .rom)
    static let jaguar: UTType = UTType(exportedAs: "com.provenance.rom.jaguar", conformingTo: .rom)
    static let jaguarCD: UTType = UTType(exportedAs: "com.provenance.rom.jaguarcd", conformingTo: .rom)
    static let macintosh: UTType = UTType(exportedAs: "com.provenance.rom.macintosh", conformingTo: .rom)
    static let mame: UTType = UTType(exportedAs: "com.provenance.rom.mame", conformingTo: .rom)
    static let masterSystem: UTType = UTType(exportedAs: "com.provenance.rom.mastersystem", conformingTo: .rom)
    static let msx: UTType = UTType(exportedAs: "com.provenance.rom.msx", conformingTo: .rom)
    static let msx2: UTType = UTType(exportedAs: "com.provenance.rom.msx2", conformingTo: .rom)
    static let music: UTType = UTType(exportedAs: "com.provenance.rom.music", conformingTo: .rom)
    static let n64: UTType = UTType(exportedAs: "com.provenance.rom.n64", conformingTo: .rom)
    static let neogeo: UTType = UTType(exportedAs: "com.provenance.rom.neogeo", conformingTo: .rom)
    static let nes: UTType = UTType(exportedAs: "com.provenance.rom.nes", conformingTo: .rom)
    static let ngp: UTType = UTType(exportedAs: "com.provenance.rom.ngp", conformingTo: .rom)
    static let ngpc: UTType = UTType(exportedAs: "com.provenance.rom.ngpc", conformingTo: .rom)
    static let odyssey2: UTType = UTType(exportedAs: "com.provenance.rom.odyssey2", conformingTo: .rom)
    static let palmos: UTType = UTType(exportedAs: "com.provenance.rom.palmos", conformingTo: .rom)
    static let pc98: UTType = UTType(exportedAs: "com.provenance.rom.pc98", conformingTo: .rom)
    static let pce: UTType = UTType(exportedAs: "com.provenance.rom.pce", conformingTo: .rom)
    static let pcecd: UTType = UTType(exportedAs: "com.provenance.rom.pcecd", conformingTo: .rom)
    static let pcfx: UTType = UTType(exportedAs: "com.provenance.rom.pcfx", conformingTo: .rom)
    static let pokemonmini: UTType = UTType(exportedAs: "com.provenance.rom.pokemonmini", conformingTo: .rom)
    static let ps2: UTType = UTType(exportedAs: "com.provenance.rom.ps2", conformingTo: .rom)
    static let ps3: UTType = UTType(exportedAs: "com.provenance.rom.ps3", conformingTo: .rom)
    static let psp: UTType = UTType(exportedAs: "com.provenance.rom.psp", conformingTo: .rom)
    static let psx: UTType = UTType(exportedAs: "com.provenance.rom.psx", conformingTo: .rom)
    static let quake: UTType = UTType(exportedAs: "com.provenance.rom.quake", conformingTo: .rom)
    static let quake2: UTType = UTType(exportedAs: "com.provenance.rom.quake2", conformingTo: .rom)
    static let retroarch: UTType = UTType(exportedAs: "com.provenance.rom.retroarch", conformingTo: .rom)
    static let saturn: UTType = UTType(exportedAs: "com.provenance.rom.saturn", conformingTo: .rom)
    static let sega32x: UTType = UTType(exportedAs: "com.provenance.rom.sega32x", conformingTo: .rom)
    static let segacd: UTType = UTType(exportedAs: "com.provenance.rom.segacd", conformingTo: .rom)
    static let sg1000: UTType = UTType(exportedAs: "com.provenance.rom.sg1000", conformingTo: .rom)
    static let sgfx: UTType = UTType(exportedAs: "com.provenance.rom.sgfx", conformingTo: .rom)
    static let snes: UTType = UTType(exportedAs: "com.provenance.rom.snes", conformingTo: .rom)
    static let supervision: UTType = UTType(exportedAs: "com.provenance.rom.supervision", conformingTo: .rom)
    static let threeDO: UTType = UTType(exportedAs: "com.provenance.rom.3do", conformingTo: .rom)
    static let threeDS: UTType = UTType(exportedAs: "com.provenance.rom.3ds", conformingTo: .rom)
    static let tic80: UTType = UTType(exportedAs: "com.provenance.rom.tic80", conformingTo: .rom)
    static let vb: UTType = UTType(exportedAs: "com.provenance.rom.vb", conformingTo: .rom)
    static let vectrex: UTType = UTType(exportedAs: "com.provenance.rom.vectrex", conformingTo: .rom)
    static let wii: UTType = UTType(exportedAs: "com.provenance.rom.wii", conformingTo: .rom)
    static let wolf3d: UTType = UTType(exportedAs: "com.provenance.rom.wolf3d", conformingTo: .rom)
    static let ws: UTType = UTType(exportedAs: "com.provenance.rom.ws", conformingTo: .rom)
    static let wsc: UTType = UTType(exportedAs: "com.provenance.rom.wsc", conformingTo: .rom)
    static let zxspectrum: UTType = UTType(exportedAs: "com.provenance.rom.zxspectrum", conformingTo: .rom)
}
#endif

#if canImport(CoreServices)
/// Instances of the UTI class represent a specific Universal Type Identifier, e.g. kUTTypeMPEG4.
public final class UTI: RawRepresentable, Equatable {
    /**
     The TagClass enum represents the supported tag classes.

     - fileExtension: kUTTagClassFilenameExtension
     - mimeType: kUTTagClassMIMEType
     - pbType: kUTTagClassNSPboardType
     - osType: kUTTagClassOSType
     */
    public enum TagClass: String {
        /// Equivalent to kUTTagClassFilenameExtension
        case fileExtension = "public.filename-extension"

        /// Equivalent to kUTTagClassMIMEType
        case mimeType = "public.mime-type"

        #if os(macOS)

            /// Equivalent to kUTTagClassNSPboardType
            case pbType = "com.apple.nspboard-type"

            /// Equivalent to kUTTagClassOSType
            case osType = "com.apple.ostype"
        #endif

        /// Convenience variable for internal use.

        fileprivate var rawCFValue: CFString {
            return rawValue as CFString
        }
    }

    public typealias RawValue = String
    public let rawValue: String

    /// Convenience variable for internal use.

    private var rawCFValue: CFString {
        return rawValue as CFString
    }

    // MARK: Initialization

    /**

     This is the designated initializer of the UTI class.

     - Parameters:
     - rawValue: A string that is a Universal Type Identifier, i.e. "com.foobar.baz" or a constant like kUTTypeMP3.
     - Returns:
     An UTI instance representing the specified rawValue.
     - Note:
     You should rarely use this method. The preferred way to initialize a known UTI is to use its static variable (i.e. UTI.pdf). You should make an extension to make your own types available as static variables.

     */

    public required init(rawValue: UTI.RawValue) {
        self.rawValue = rawValue
    }

    /**

     Initialize an UTI with a tag of a specified class.

     - Parameters:
     - tagClass: The class of the tag.
     - value: The value of the tag.
     - conformingTo: If specified, the returned UTI must conform to this UTI. If nil is specified, this parameter is ignored. The default is nil.
     - Returns:
     An UTI instance representing the specified rawValue. If no known UTI with the specified tags is found, a dynamic UTI is created.
     - Note:
     You should rarely need this method. It's usually simpler to use one of the specialized initialzers like
     ```convenience init?(withExtension fileExtension: String, conformingTo conforming: UTI? = nil)```
     */

    public convenience init(withTagClass tagClass: TagClass, value: String, conformingTo conforming: UTI? = nil) {
        let unmanagedIdentifier = UTTypeCreatePreferredIdentifierForTag(tagClass.rawCFValue, value as CFString, conforming?.rawCFValue)

        // UTTypeCreatePreferredIdentifierForTag only returns nil if the tag class is unknwown, which can't happen to us since we use an
        // enum of known values. Hence we can force-cast the result.

        let identifier = (unmanagedIdentifier?.takeRetainedValue() as String?)!

        self.init(rawValue: identifier)
    }

    /**

     Initialize an UTI with a file extension.

     - Parameters:
     - withExtension: The file extension (e.g. "txt").
     - conformingTo: If specified, the returned UTI must conform to this UTI. If nil is specified, this parameter is ignored. The default is nil.
     - Returns:
     An UTI corresponding to the specified values.
     **/

    public convenience init(withExtension fileExtension: String, conformingTo conforming: UTI? = nil) {
        self.init(withTagClass: .fileExtension, value: fileExtension, conformingTo: conforming)
    }

    /**

     Initialize an UTI with a MIME type.

     - Parameters:
     - mimeType: The MIME type (e.g. "text/plain").
     - conformingTo: If specified, the returned UTI must conform to this UTI. If nil is specified, this parameter is ignored. The default is nil.
     - Returns:
     An UTI corresponding to the specified values.
     */

    public convenience init(withMimeType mimeType: String, conformingTo conforming: UTI? = nil) {
        self.init(withTagClass: .mimeType, value: mimeType, conformingTo: conforming)
    }

    #if os(macOS)

        /**

         Initialize an UTI with a pasteboard type.

         - Parameters:
         - pbType: The pasteboard type (e.g. NSPDFPboardType).
         - conformingTo: If specified, the returned UTI must conform to this UTI. If nil is specified, this parameter is ignored. The default is nil.
         - Returns:
         An UTI corresponding to the specified values.
         */
        public convenience init(withPBType pbType: String, conformingTo conforming: UTI? = nil) {
            self.init(withTagClass: .pbType, value: pbType, conformingTo: conforming)
        }

        /**
         Initialize an UTI with a OSType.

         - Parameters:
         - osType: The OSType type as a string (e.g. "PDF ").
         - conformingTo: If specified, the returned UTI must conform to this UTI. If nil is specified, this parameter is ignored. The default is nil.
         - Returns:
         An UTI corresponding to the specified values.
         - Note:
         You can use the variable ```OSType.string``` to get a string from an actual OSType.
         */

        public convenience init(withOSType osType: String, conformingTo conforming: UTI? = nil) {
            self.init(withTagClass: .osType, value: osType, conformingTo: conforming)
        }

    #endif

    // MARK: Accessing Tags

    /**

     Returns the tag with the specified class.

     - Parameters:
     - tagClass: The tag class to return.
     - Returns:
     The requested tag, or nil if there is no tag of the specified class.
     */

    public func tag(with tagClass: TagClass) -> String? {
        let unmanagedTag = UTTypeCopyPreferredTagWithClass(rawCFValue, tagClass.rawCFValue)

        guard let tag = unmanagedTag?.takeRetainedValue() as String? else {
            return nil
        }

        return tag
    }

    /// Return the file extension that corresponds the the UTI. Returns nil if not available.

    public var fileExtension: String? {
        return tag(with: .fileExtension)
    }

    /// Return the MIME type that corresponds the the UTI. Returns nil if not available.

    public var mimeType: String? {
        return tag(with: .mimeType)
    }

    #if os(macOS)

        /// Return the pasteboard type that corresponds the the UTI. Returns nil if not available.

        public var pbType: String? {
            return tag(with: .pbType)
        }

        /// Return the OSType as a string that corresponds the the UTI. Returns nil if not available.
        /// - Note: you can use the ```init(with string: String)``` initializer to construct an actual OSType from the returnes string.

        public var osType: String? {
            return tag(with: .osType)
        }

    #endif

    /**

     Returns all tags of the specified tag class.

     - Parameters:
     - tagClass: The class of the requested tags.
     - Returns:
     An array of all tags of the receiver of the specified class.
     */

    public func tags(with tagClass: TagClass) -> [String] {
        let unmanagedTags = UTTypeCopyAllTagsWithClass(rawCFValue, tagClass.rawCFValue)

        guard let tags = unmanagedTags?.takeRetainedValue() as? [CFString] else {
            return []
        }

        return tags as [String]
    }

    // MARK: List all UTIs associated with a tag

    /**
     Returns all UTIs that are associated with a specified tag.

     - Parameters:
     - tag: The class of the specified tag.
     - value: The value of the tag.
     - conforming: If specified, the returned UTIs must conform to this UTI. If nil is specified, this parameter is ignored. The default is nil.
     - Returns:
     An array of all UTIs that satisfy the specified parameters.
     */

    public static func utis(for tag: TagClass, value: String, conformingTo conforming: UTI? = nil) -> [UTI] {
        let unmanagedIdentifiers = UTTypeCreateAllIdentifiersForTag(tag.rawCFValue, value as CFString, conforming?.rawCFValue)

        guard let identifiers = unmanagedIdentifiers?.takeRetainedValue() as? [CFString] else {
            return []
        }

        return identifiers.compactMap { UTI(rawValue: $0 as String) }
    }

    // MARK: Equality and Conformance to other UTIs

    /**

     Checks if the receiver conforms to a specified UTI.

     - Parameters:
     - otherUTI: The UTI to which the receiver is compared.
     - Returns:
     ```true``` if the receiver conforms to the specified UTI, ```false```otherwise.
     */

    public func conforms(to otherUTI: UTI) -> Bool {
        return UTTypeConformsTo(rawCFValue, otherUTI.rawCFValue) as Bool
    }

    public static func == (lhs: UTI, rhs: UTI) -> Bool {
        return UTTypeEqual(lhs.rawCFValue, rhs.rawCFValue) as Bool
    }

    // MARK: Accessing Information about an UTI

    /// Returns the localized, user-readable type description string associated with a uniform type identifier.

    public var description: String? {
        let unmanagedDescription = UTTypeCopyDescription(rawCFValue)

        guard let description = unmanagedDescription?.takeRetainedValue() as String? else {
            return nil
        }

        return description
    }

    /// Returns a uniform type’s declaration as a Dictionary, or nil if if no declaration for that type can be found.

    public var declaration: [AnyHashable: Any]? {
        let unmanagedDeclaration = UTTypeCopyDeclaration(rawCFValue)

        guard let declaration = unmanagedDeclaration?.takeRetainedValue() as? [AnyHashable: Any] else {
            return nil
        }

        return declaration
    }

    /// Returns the location of a bundle containing the declaration for a type, or nil if the bundle could not be located.

    public var declaringBundleURL: URL? {
        let unmanagedURL = UTTypeCopyDeclaringBundleURL(rawCFValue)

        guard let url = unmanagedURL?.takeRetainedValue() as URL? else {
            return nil
        }

        return url
    }

    /// Returns ```true``` if the receiver is a dynamic UTI.

    public var isDynamic: Bool {
        return UTTypeIsDynamic(rawCFValue)
    }
}
#else
/// Minimal UTI implementation for platforms without CoreServices (e.g. Linux).
public final class UTI: RawRepresentable, Equatable {
    public enum TagClass: String {
        case fileExtension = "public.filename-extension"
        case mimeType = "public.mime-type"
        #if os(macOS)
        case pbType = "com.apple.nspboard-type"
        case osType = "com.apple.ostype"
        #endif
    }

    public typealias RawValue = String
    public let rawValue: String

    public required init(rawValue: UTI.RawValue) {
        self.rawValue = rawValue
    }

    public convenience init(withTagClass tagClass: TagClass, value: String, conformingTo conforming: UTI? = nil) {
        self.init(rawValue: "public.data")
    }

    public convenience init(withExtension fileExtension: String, conformingTo conforming: UTI? = nil) {
        self.init(withTagClass: .fileExtension, value: fileExtension, conformingTo: conforming)
    }

    public convenience init(withMimeType mimeType: String, conformingTo conforming: UTI? = nil) {
        self.init(withTagClass: .mimeType, value: mimeType, conformingTo: conforming)
    }

    #if os(macOS)
    public convenience init(withPBType pbType: String, conformingTo conforming: UTI? = nil) {
        self.init(withTagClass: .pbType, value: pbType, conformingTo: conforming)
    }
    public convenience init(withOSType osType: String, conformingTo conforming: UTI? = nil) {
        self.init(withTagClass: .osType, value: osType, conformingTo: conforming)
    }
    #endif

    public func tag(with tagClass: TagClass) -> String? { nil }
    public var fileExtension: String? { tag(with: .fileExtension) }
    public var mimeType: String? { tag(with: .mimeType) }

    #if os(macOS)
    public var pbType: String? { tag(with: .pbType) }
    public var osType: String? { tag(with: .osType) }
    #endif

    public func tags(with tagClass: TagClass) -> [String] { [] }
    public static func utis(for tag: TagClass, value: String, conformingTo conforming: UTI? = nil) -> [UTI] { [] }
    public func conforms(to otherUTI: UTI) -> Bool { rawValue == otherUTI.rawValue }
    public static func == (lhs: UTI, rhs: UTI) -> Bool { lhs.rawValue == rhs.rawValue }
    public var description: String? { nil }
    public var declaration: [AnyHashable: Any]? { nil }
    public var declaringBundleURL: URL? { nil }
    public var isDynamic: Bool { false }
}
#endif

// MARK: System defined UTIs

#if canImport(UniformTypeIdentifiers)
public extension UTI {
    nonisolated(unsafe) static let _3DContent = UTI(rawValue: UTType.threeDContent.identifier as String)
    nonisolated(unsafe) static let aliasFile = UTI(rawValue: UTType.aliasFile.identifier as String)
    nonisolated(unsafe) static let appleICNS = UTI(rawValue: UTType.icns.identifier as String)
    nonisolated(unsafe) static let appleProtectedMPEG4Audio = UTI(rawValue: UTType.appleProtectedMPEG4Audio.identifier as String)
    nonisolated(unsafe) static let appleProtectedMPEG4Video = UTI(rawValue: UTType.appleProtectedMPEG4Video.identifier as String)
    nonisolated(unsafe) static let appleScript = UTI(rawValue: UTType.appleScript.identifier as String)
    nonisolated(unsafe) static let application = UTI(rawValue: UTType.application.identifier as String)
    nonisolated(unsafe) static let applicationBundle = UTI(rawValue: UTType.applicationBundle.identifier as String)
    nonisolated(unsafe) static let applicationExtension = UTI(rawValue: UTType.applicationExtension.identifier as String)
    nonisolated(unsafe) static let archive = UTI(rawValue: UTType.archive.identifier as String)
    nonisolated(unsafe) static let assemblyLanguageSource = UTI(rawValue: UTType.assemblyLanguageSource.identifier as String)
    nonisolated(unsafe) static let audio = UTI(rawValue: UTType.audio.identifier as String)
    nonisolated(unsafe) static let audiovisualContent = UTI(rawValue: UTType.audiovisualContent.identifier as String)
    nonisolated(unsafe) static let aviMovie = UTI(rawValue: UTType.avi.identifier as String)
    nonisolated(unsafe) static let binaryPropertyList = UTI(rawValue: UTType.binaryPropertyList.identifier as String)
    nonisolated(unsafe) static let bmp = UTI(rawValue: UTType.bmp.identifier as String)
    nonisolated(unsafe) static let bookmark = UTI(rawValue: UTType.bookmark.identifier as String)
    nonisolated(unsafe) static let bundle = UTI(rawValue: UTType.bundle.identifier as String)
    nonisolated(unsafe) static let bzip2Archive = UTI(rawValue: UTType.bz2.identifier as String)
    nonisolated(unsafe) static let cHeader = UTI(rawValue: UTType.cHeader.identifier as String)
    nonisolated(unsafe) static let cPlusPlusHeader = UTI(rawValue: UTType.cPlusPlusHeader.identifier as String)
    nonisolated(unsafe) static let cPlusPlusSource = UTI(rawValue: UTType.cPlusPlusSource.identifier as String)
    nonisolated(unsafe) static let cSource = UTI(rawValue: UTType.cSource.identifier as String)
    nonisolated(unsafe) static let calendarEvent = UTI(rawValue: UTType.calendarEvent.identifier as String)
    nonisolated(unsafe) static let commaSeparatedText = UTI(rawValue: UTType.commaSeparatedText.identifier as String)
    nonisolated(unsafe) static let compositeContent = UTI(rawValue: UTType.compositeContent.identifier as String)
    nonisolated(unsafe) static let contact = UTI(rawValue: UTType.contact.identifier as String)
    nonisolated(unsafe) static let content = UTI(rawValue: UTType.content.identifier as String)
    nonisolated(unsafe) static let data = UTI(rawValue: UTType.data.identifier as String)
    nonisolated(unsafe) static let database = UTI(rawValue: UTType.database.identifier as String)
    nonisolated(unsafe) static let delimitedText = UTI(rawValue: UTType.delimitedText.identifier as String)
    nonisolated(unsafe) static let directory = UTI(rawValue: UTType.directory.identifier as String)
    nonisolated(unsafe) static let diskImage = UTI(rawValue: UTType.diskImage.identifier as String)
    nonisolated(unsafe) static let electronicPublication = UTI(rawValue: UTType.epub.identifier as String)
    nonisolated(unsafe) static let emailMessage = UTI(rawValue: UTType.emailMessage.identifier as String)
    nonisolated(unsafe) static let executable = UTI(rawValue: UTType.executable.identifier as String)
    nonisolated(unsafe) static let fileURL = UTI(rawValue: UTType.fileURL.identifier as String)
    nonisolated(unsafe) static let flatRTFD = UTI(rawValue: UTType.flatRTFD.identifier as String)
    nonisolated(unsafe) static let folder = UTI(rawValue: UTType.folder.identifier as String)
    nonisolated(unsafe) static let font = UTI(rawValue: UTType.font.identifier as String)
    nonisolated(unsafe) static let framework = UTI(rawValue: UTType.framework.identifier as String)
    nonisolated(unsafe) static let gif = UTI(rawValue: UTType.gif.identifier as String)
    nonisolated(unsafe) static let gnuZipArchive = UTI(rawValue: UTType.gzip.identifier as String)
    nonisolated(unsafe) static let html = UTI(rawValue: UTType.html.identifier as String)
    nonisolated(unsafe) static let ico = UTI(rawValue: UTType.ico.identifier as String)
    nonisolated(unsafe) static let image = UTI(rawValue: UTType.image.identifier as String)
    nonisolated(unsafe) static let internetLocation = UTI(rawValue: UTType.internetLocation.identifier as String)
    nonisolated(unsafe) static let item = UTI(rawValue: UTType.item.identifier as String)
    nonisolated(unsafe) static let javaScript = UTI(rawValue: UTType.javaScript.identifier as String)
    nonisolated(unsafe) static let jpeg = UTI(rawValue: UTType.jpeg.identifier as String)
    nonisolated(unsafe) static let json = UTI(rawValue: UTType.json.identifier as String)
    nonisolated(unsafe) static let livePhoto = UTI(rawValue: UTType.livePhoto.identifier as String)
    nonisolated(unsafe) static let log = UTI(rawValue: UTType.log.identifier as String)
    nonisolated(unsafe) static let m3UPlaylist = UTI(rawValue: UTType.m3uPlaylist.identifier as String)
    nonisolated(unsafe) static let message = UTI(rawValue: UTType.message.identifier as String)
    nonisolated(unsafe) static let midiAudio = UTI(rawValue: UTType.midi.identifier as String)
    nonisolated(unsafe) static let mountPoint = UTI(rawValue: UTType.mountPoint.identifier as String)
    nonisolated(unsafe) static let movie = UTI(rawValue: UTType.movie.identifier as String)
    nonisolated(unsafe) static let mp3 = UTI(rawValue: UTType.mp3.identifier as String)
    nonisolated(unsafe) static let mpeg = UTI(rawValue: UTType.mpeg.identifier as String)
    nonisolated(unsafe) static let mpeg2TransportStream = UTI(rawValue: UTType.mpeg2TransportStream.identifier as String)
    nonisolated(unsafe) static let mpeg2Video = UTI(rawValue: UTType.mpeg2Video.identifier as String)
    nonisolated(unsafe) static let mpeg4 = UTI(rawValue: UTType.mpeg4Movie.identifier as String)
    nonisolated(unsafe) static let mpeg4Audio = UTI(rawValue: UTType.mpeg4Audio.identifier as String)
    nonisolated(unsafe) static let objectiveCPlusPlusSource = UTI(rawValue: UTType.objectiveCPlusPlusSource.identifier as String)
    nonisolated(unsafe) static let objectiveCSource = UTI(rawValue: UTType.objectiveCSource.identifier as String)
    nonisolated(unsafe) static let osaScript = UTI(rawValue: UTType.osaScript.identifier as String)
    nonisolated(unsafe) static let osaScriptBundle = UTI(rawValue: UTType.osaScriptBundle.identifier as String)
    nonisolated(unsafe) static let package = UTI(rawValue: UTType.package.identifier as String)
    nonisolated(unsafe) static let pdf = UTI(rawValue: UTType.pdf.identifier as String)
    nonisolated(unsafe) static let perlScript = UTI(rawValue: UTType.perlScript.identifier as String)
    nonisolated(unsafe) static let phpScript = UTI(rawValue: UTType.phpScript.identifier as String)
    nonisolated(unsafe) static let pkcs12 = UTI(rawValue: UTType.pkcs12.identifier as String)
    nonisolated(unsafe) static let plainText = UTI(rawValue: UTType.plainText.identifier as String)
    nonisolated(unsafe) static let playlist = UTI(rawValue: UTType.playlist.identifier as String)
    nonisolated(unsafe) static let pluginBundle = UTI(rawValue: UTType.pluginBundle.identifier as String)
    nonisolated(unsafe) static let png = UTI(rawValue: UTType.png.identifier as String)
    nonisolated(unsafe) static let presentation = UTI(rawValue: UTType.presentation.identifier as String)
    nonisolated(unsafe) static let propertyList = UTI(rawValue: UTType.propertyList.identifier as String)
    nonisolated(unsafe) static let pythonScript = UTI(rawValue: UTType.pythonScript.identifier as String)
    nonisolated(unsafe) static let quickLookGenerator = UTI(rawValue: UTType.quickLookGenerator.identifier as String)
    nonisolated(unsafe) static let quickTimeMovie = UTI(rawValue: UTType.quickTimeMovie.identifier as String)
    nonisolated(unsafe) static let rawImage = UTI(rawValue: UTType.rawImage.identifier as String)
    nonisolated(unsafe) static let resolvable = UTI(rawValue: UTType.resolvable.identifier as String)
    nonisolated(unsafe) static let rtf = UTI(rawValue: UTType.rtf.identifier as String)
    nonisolated(unsafe) static let rtfd = UTI(rawValue: UTType.rtfd.identifier as String)
    nonisolated(unsafe) static let rubyScript = UTI(rawValue: UTType.rubyScript.identifier as String)
    nonisolated(unsafe) static let scalableVectorGraphics = UTI(rawValue: UTType.svg.identifier as String)
    nonisolated(unsafe) static let script = UTI(rawValue: UTType.script.identifier as String)
    nonisolated(unsafe) static let shellScript = UTI(rawValue: UTType.shellScript.identifier as String)
    nonisolated(unsafe) static let sourceCode = UTI(rawValue: UTType.sourceCode.identifier as String)
    nonisolated(unsafe) static let spotlightImporter = UTI(rawValue: UTType.spotlightImporter.identifier as String)
    nonisolated(unsafe) static let spreadsheet = UTI(rawValue: UTType.spreadsheet.identifier as String)
    nonisolated(unsafe) static let swiftSource = UTI(rawValue: UTType.swiftSource.identifier as String)
    nonisolated(unsafe) static let symLink = UTI(rawValue: UTType.symbolicLink.identifier as String)
    nonisolated(unsafe) static let systemPreferencesPane = UTI(rawValue: UTType.systemPreferencesPane.identifier as String)
    nonisolated(unsafe) static let tabSeparatedText = UTI(rawValue: UTType.tabSeparatedText.identifier as String)
    nonisolated(unsafe) static let text = UTI(rawValue: UTType.text.identifier as String)
    nonisolated(unsafe) static let tiff = UTI(rawValue: UTType.tiff.identifier as String)
    nonisolated(unsafe) static let toDoItem = UTI(rawValue: UTType.toDoItem.identifier as String)
    nonisolated(unsafe) static let unixExecutable = UTI(rawValue: UTType.unixExecutable.identifier as String)
    nonisolated(unsafe) static let url = UTI(rawValue: UTType.url.identifier as String)
    nonisolated(unsafe) static let urlBookmarkData = UTI(rawValue: UTType.urlBookmarkData.identifier as String)
    nonisolated(unsafe) static let utf16ExternalPlainText = UTI(rawValue: UTType.utf16ExternalPlainText.identifier as String)
    nonisolated(unsafe) static let utf16PlainText = UTI(rawValue: UTType.utf16PlainText.identifier as String)
    nonisolated(unsafe) static let utf8PlainText = UTI(rawValue: UTType.utf8PlainText.identifier as String)
    nonisolated(unsafe) static let utf8TabSeparatedText = UTI(rawValue: UTType.utf8TabSeparatedText.identifier as String)
    nonisolated(unsafe) static let vCard = UTI(rawValue: UTType.vCard.identifier as String)
    nonisolated(unsafe) static let video = UTI(rawValue: UTType.video.identifier as String)
    nonisolated(unsafe) static let volume = UTI(rawValue: UTType.volume.identifier as String)
    nonisolated(unsafe) static let waveformAudio = UTI(rawValue: UTType.wav.identifier as String)
    nonisolated(unsafe) static let webArchive = UTI(rawValue: UTType.webArchive.identifier as String)
    nonisolated(unsafe) static let x509Certificate = UTI(rawValue: UTType.x509Certificate.identifier as String)
    nonisolated(unsafe) static let xml = UTI(rawValue: UTType.xml.identifier as String)
    nonisolated(unsafe) static let xmlPropertyList = UTI(rawValue: UTType.xmlPropertyList.identifier as String)
    nonisolated(unsafe) static let xpcService = UTI(rawValue: UTType.xpcService.identifier as String)
    nonisolated(unsafe) static let zipArchive = UTI(rawValue: UTType.zip.identifier as String)
}
#endif

#if os(OSX)

    extension OSType {
        /// Returns the OSType encoded as a String.

        var string: String {
            let unmanagedString = UTCreateStringForOSType(self)

            return unmanagedString.takeRetainedValue() as String
        }

        /// Initializes a OSType from a String.
        ///
        /// - Parameter string: A String representing an OSType.

        init(with string: String) {
            self = UTGetOSTypeFromString(string as CFString)
        }
    }

#endif
