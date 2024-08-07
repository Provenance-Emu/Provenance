//
//  UTI.swift
//  fseventstool
//
//  Created by Matthias Keiser on 09.01.17.
//  Copyright © 2017 Tristan Inc. All rights reserved.
//

import Foundation

import CoreServices

public extension UTI {
    nonisolated(unsafe) static let rom = UTI(rawValue: "com.provenance.rom")
    nonisolated(unsafe) static let bios = UTI(rawValue: "com.provenance.rom")
    nonisolated(unsafe) static let artwork = UTI(rawValue: "com.provenance.artwork")
    nonisolated(unsafe) static let savestate = UTI(rawValue: "com.provenance.savestate")
    nonisolated(unsafe) static let sevenZipArchive = UTI(rawValue: "org.7-zip.7-zip-archive")
    nonisolated(unsafe) static let rar = UTI(rawValue: "com.rarlab.rar-archive")
}

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers

// also declare the content type in the Info.plist
@available(iOS 14.0, tvOS 14.0, *)
public extension UTType {
    static let rom: UTType = UTType(importedAs: "com.provenance.rom",  conformingTo: .data)
    static let bios: UTType = UTType(importedAs: "com.provenance.rom",  conformingTo: .data)
    static let artwork: UTType = UTType(importedAs: "com.provenance.artwork", conformingTo: .image)
    static let savestate: UTType = UTType(exportedAs: "com.provenance.savestate", conformingTo: .data)
    static let sevenZipArchive: UTType = UTType(importedAs: "org.7-zip.7-zip-archive", conformingTo: .archive)
    static let rar: UTType = UTType(importedAs: "com.rarlab.rar-archive", conformingTo: .archive)
}
#endif

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

// MARK: System defined UTIs

public extension UTI {
    nonisolated(unsafe) static let item = UTI(rawValue: kUTTypeItem as String)
    nonisolated(unsafe) static let content = UTI(rawValue: kUTTypeContent as String)
    nonisolated(unsafe) static let compositeContent = UTI(rawValue: kUTTypeCompositeContent as String)
    nonisolated(unsafe) static let message = UTI(rawValue: kUTTypeMessage as String)
    nonisolated(unsafe) static let contact = UTI(rawValue: kUTTypeContact as String)
    nonisolated(unsafe) static let archive = UTI(rawValue: kUTTypeArchive as String)
    nonisolated(unsafe) static let diskImage = UTI(rawValue: kUTTypeDiskImage as String)
    nonisolated(unsafe) static let data = UTI(rawValue: kUTTypeData as String)
    nonisolated(unsafe) static let directory = UTI(rawValue: kUTTypeDirectory as String)
    nonisolated(unsafe) static let resolvable = UTI(rawValue: kUTTypeResolvable as String)
    nonisolated(unsafe) static let symLink = UTI(rawValue: kUTTypeSymLink as String)
    nonisolated(unsafe) static let executable = UTI(rawValue: kUTTypeExecutable as String)
    nonisolated(unsafe) static let mountPoint = UTI(rawValue: kUTTypeMountPoint as String)
    nonisolated(unsafe) static let aliasFile = UTI(rawValue: kUTTypeAliasFile as String)
    nonisolated(unsafe) static let aliasRecord = UTI(rawValue: kUTTypeAliasRecord as String)
    nonisolated(unsafe) static let urlBookmarkData = UTI(rawValue: kUTTypeURLBookmarkData as String)
    nonisolated(unsafe) static let url = UTI(rawValue: kUTTypeURL as String)
    nonisolated(unsafe) static let fileURL = UTI(rawValue: kUTTypeFileURL as String)
    nonisolated(unsafe) static let text = UTI(rawValue: kUTTypeText as String)
    nonisolated(unsafe) static let plainText = UTI(rawValue: kUTTypePlainText as String)
    nonisolated(unsafe) static let utf8PlainText = UTI(rawValue: kUTTypeUTF8PlainText as String)
    nonisolated(unsafe) static let utf16ExternalPlainText = UTI(rawValue: kUTTypeUTF16ExternalPlainText as String)
    nonisolated(unsafe) static let utf16PlainText = UTI(rawValue: kUTTypeUTF16PlainText as String)
    nonisolated(unsafe) static let delimitedText = UTI(rawValue: kUTTypeDelimitedText as String)
    nonisolated(unsafe) static let commaSeparatedText = UTI(rawValue: kUTTypeCommaSeparatedText as String)
    nonisolated(unsafe) static let tabSeparatedText = UTI(rawValue: kUTTypeTabSeparatedText as String)
    nonisolated(unsafe) static let utf8TabSeparatedText = UTI(rawValue: kUTTypeUTF8TabSeparatedText as String)
    nonisolated(unsafe) static let rtf = UTI(rawValue: kUTTypeRTF as String)
    nonisolated(unsafe) static let html = UTI(rawValue: kUTTypeHTML as String)
    nonisolated(unsafe) static let xml = UTI(rawValue: kUTTypeXML as String)
    nonisolated(unsafe) static let sourceCode = UTI(rawValue: kUTTypeSourceCode as String)
    nonisolated(unsafe) static let assemblyLanguageSource = UTI(rawValue: kUTTypeAssemblyLanguageSource as String)
    nonisolated(unsafe) static let cSource = UTI(rawValue: kUTTypeCSource as String)
    nonisolated(unsafe) static let objectiveCSource = UTI(rawValue: kUTTypeObjectiveCSource as String)
    nonisolated(unsafe) static let swiftSource = UTI(rawValue: kUTTypeSwiftSource as String)
    nonisolated(unsafe) static let cPlusPlusSource = UTI(rawValue: kUTTypeCPlusPlusSource as String)
    nonisolated(unsafe) static let objectiveCPlusPlusSource = UTI(rawValue: kUTTypeObjectiveCPlusPlusSource as String)
    nonisolated(unsafe) static let cHeader = UTI(rawValue: kUTTypeCHeader as String)
    nonisolated(unsafe) static let cPlusPlusHeader = UTI(rawValue: kUTTypeCPlusPlusHeader as String)
    nonisolated(unsafe) static let javaSource = UTI(rawValue: kUTTypeJavaSource as String)
    nonisolated(unsafe) static let script = UTI(rawValue: kUTTypeScript as String)
    nonisolated(unsafe) static let appleScript = UTI(rawValue: kUTTypeAppleScript as String)
    nonisolated(unsafe) static let osaScript = UTI(rawValue: kUTTypeOSAScript as String)
    nonisolated(unsafe) static let osaScriptBundle = UTI(rawValue: kUTTypeOSAScriptBundle as String)
    nonisolated(unsafe) static let javaScript = UTI(rawValue: kUTTypeJavaScript as String)
    nonisolated(unsafe) static let shellScript = UTI(rawValue: kUTTypeShellScript as String)
    nonisolated(unsafe) static let perlScript = UTI(rawValue: kUTTypePerlScript as String)
    nonisolated(unsafe) static let pythonScript = UTI(rawValue: kUTTypePythonScript as String)
    nonisolated(unsafe) static let rubyScript = UTI(rawValue: kUTTypeRubyScript as String)
    nonisolated(unsafe) static let phpScript = UTI(rawValue: kUTTypePHPScript as String)
    nonisolated(unsafe) static let json = UTI(rawValue: kUTTypeJSON as String)
    nonisolated(unsafe) static let propertyList = UTI(rawValue: kUTTypePropertyList as String)
    nonisolated(unsafe) static let xmlPropertyList = UTI(rawValue: kUTTypeXMLPropertyList as String)
    nonisolated(unsafe) static let binaryPropertyList = UTI(rawValue: kUTTypeBinaryPropertyList as String)
    nonisolated(unsafe) static let pdf = UTI(rawValue: kUTTypePDF as String)
    nonisolated(unsafe) static let rtfd = UTI(rawValue: kUTTypeRTFD as String)
    nonisolated(unsafe) static let flatRTFD = UTI(rawValue: kUTTypeFlatRTFD as String)
    nonisolated(unsafe) static let txnTextAndMultimediaData = UTI(rawValue: kUTTypeTXNTextAndMultimediaData as String)
    nonisolated(unsafe) static let webArchive = UTI(rawValue: kUTTypeWebArchive as String)
    nonisolated(unsafe) static let image = UTI(rawValue: kUTTypeImage as String)
    nonisolated(unsafe) static let jpeg = UTI(rawValue: kUTTypeJPEG as String)
    nonisolated(unsafe) static let jpeg2000 = UTI(rawValue: kUTTypeJPEG2000 as String)
    nonisolated(unsafe) static let tiff = UTI(rawValue: kUTTypeTIFF as String)
    nonisolated(unsafe) static let pict = UTI(rawValue: kUTTypePICT as String)
    nonisolated(unsafe) static let gif = UTI(rawValue: kUTTypeGIF as String)
    nonisolated(unsafe) static let png = UTI(rawValue: kUTTypePNG as String)
    nonisolated(unsafe) static let quickTimeImage = UTI(rawValue: kUTTypeQuickTimeImage as String)
    nonisolated(unsafe) static let appleICNS = UTI(rawValue: kUTTypeAppleICNS as String)
    nonisolated(unsafe) static let bmp = UTI(rawValue: kUTTypeBMP as String)
    nonisolated(unsafe) static let ico = UTI(rawValue: kUTTypeICO as String)
    nonisolated(unsafe) static let rawImage = UTI(rawValue: kUTTypeRawImage as String)
    nonisolated(unsafe) static let scalableVectorGraphics = UTI(rawValue: kUTTypeScalableVectorGraphics as String)
    nonisolated(unsafe) static let livePhoto = UTI(rawValue: kUTTypeLivePhoto as String)
    nonisolated(unsafe) static let audiovisualContent = UTI(rawValue: kUTTypeAudiovisualContent as String)
    nonisolated(unsafe) static let movie = UTI(rawValue: kUTTypeMovie as String)
    nonisolated(unsafe) static let video = UTI(rawValue: kUTTypeVideo as String)
    nonisolated(unsafe) static let audio = UTI(rawValue: kUTTypeAudio as String)
    nonisolated(unsafe) static let quickTimeMovie = UTI(rawValue: kUTTypeQuickTimeMovie as String)
    nonisolated(unsafe) static let mpeg = UTI(rawValue: kUTTypeMPEG as String)
    nonisolated(unsafe) static let mpeg2Video = UTI(rawValue: kUTTypeMPEG2Video as String)
    nonisolated(unsafe) static let mpeg2TransportStream = UTI(rawValue: kUTTypeMPEG2TransportStream as String)
    nonisolated(unsafe) static let mp3 = UTI(rawValue: kUTTypeMP3 as String)
    nonisolated(unsafe) static let mpeg4 = UTI(rawValue: kUTTypeMPEG4 as String)
    nonisolated(unsafe) static let mpeg4Audio = UTI(rawValue: kUTTypeMPEG4Audio as String)
    nonisolated(unsafe) static let appleProtectedMPEG4Audio = UTI(rawValue: kUTTypeAppleProtectedMPEG4Audio as String)
    nonisolated(unsafe) static let appleProtectedMPEG4Video = UTI(rawValue: kUTTypeAppleProtectedMPEG4Video as String)
    nonisolated(unsafe) static let aviMovie = UTI(rawValue: kUTTypeAVIMovie as String)
    nonisolated(unsafe) static let audioInterchangeFileFormat = UTI(rawValue: kUTTypeAudioInterchangeFileFormat as String)
    nonisolated(unsafe) static let waveformAudio = UTI(rawValue: kUTTypeWaveformAudio as String)
    nonisolated(unsafe) static let midiAudio = UTI(rawValue: kUTTypeMIDIAudio as String)
    nonisolated(unsafe) static let playlist = UTI(rawValue: kUTTypePlaylist as String)
    nonisolated(unsafe) static let m3UPlaylist = UTI(rawValue: kUTTypeM3UPlaylist as String)
    nonisolated(unsafe) static let folder = UTI(rawValue: kUTTypeFolder as String)
    nonisolated(unsafe) static let volume = UTI(rawValue: kUTTypeVolume as String)
    nonisolated(unsafe) static let package = UTI(rawValue: kUTTypePackage as String)
    nonisolated(unsafe) static let bundle = UTI(rawValue: kUTTypeBundle as String)
    nonisolated(unsafe) static let pluginBundle = UTI(rawValue: kUTTypePluginBundle as String)
    nonisolated(unsafe) static let spotlightImporter = UTI(rawValue: kUTTypeSpotlightImporter as String)
    nonisolated(unsafe) static let quickLookGenerator = UTI(rawValue: kUTTypeQuickLookGenerator as String)
    nonisolated(unsafe) static let xpcService = UTI(rawValue: kUTTypeXPCService as String)
    nonisolated(unsafe) static let framework = UTI(rawValue: kUTTypeFramework as String)
    nonisolated(unsafe) static let application = UTI(rawValue: kUTTypeApplication as String)
    nonisolated(unsafe) static let applicationBundle = UTI(rawValue: kUTTypeApplicationBundle as String)
    nonisolated(unsafe) static let applicationFile = UTI(rawValue: kUTTypeApplicationFile as String)
    nonisolated(unsafe) static let unixExecutable = UTI(rawValue: kUTTypeUnixExecutable as String)
    nonisolated(unsafe) static let windowsExecutable = UTI(rawValue: kUTTypeWindowsExecutable as String)
    nonisolated(unsafe) static let javaClass = UTI(rawValue: kUTTypeJavaClass as String)
    nonisolated(unsafe) static let javaArchive = UTI(rawValue: kUTTypeJavaArchive as String)
    nonisolated(unsafe) static let systemPreferencesPane = UTI(rawValue: kUTTypeSystemPreferencesPane as String)
    nonisolated(unsafe) static let gnuZipArchive = UTI(rawValue: kUTTypeGNUZipArchive as String)
    nonisolated(unsafe) static let bzip2Archive = UTI(rawValue: kUTTypeBzip2Archive as String)
    nonisolated(unsafe) static let zipArchive = UTI(rawValue: kUTTypeZipArchive as String)
    nonisolated(unsafe) static let spreadsheet = UTI(rawValue: kUTTypeSpreadsheet as String)
    nonisolated(unsafe) static let presentation = UTI(rawValue: kUTTypePresentation as String)
    nonisolated(unsafe) static let database = UTI(rawValue: kUTTypeDatabase as String)
    nonisolated(unsafe) static let vCard = UTI(rawValue: kUTTypeVCard as String)
    nonisolated(unsafe) static let toDoItem = UTI(rawValue: kUTTypeToDoItem as String)
    nonisolated(unsafe) static let calendarEvent = UTI(rawValue: kUTTypeCalendarEvent as String)
    nonisolated(unsafe) static let emailMessage = UTI(rawValue: kUTTypeEmailMessage as String)
    nonisolated(unsafe) static let internetLocation = UTI(rawValue: kUTTypeInternetLocation as String)
    nonisolated(unsafe) static let inkText = UTI(rawValue: kUTTypeInkText as String)
    nonisolated(unsafe) static let font = UTI(rawValue: kUTTypeFont as String)
    nonisolated(unsafe) static let bookmark = UTI(rawValue: kUTTypeBookmark as String)
    nonisolated(unsafe) static let _3DContent = UTI(rawValue: kUTType3DContent as String)
    nonisolated(unsafe) static let pkcs12 = UTI(rawValue: kUTTypePKCS12 as String)
    nonisolated(unsafe) static let x509Certificate = UTI(rawValue: kUTTypeX509Certificate as String)
    nonisolated(unsafe) static let electronicPublication = UTI(rawValue: kUTTypeElectronicPublication as String)
    nonisolated(unsafe) static let log = UTI(rawValue: kUTTypeLog as String)
}

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
