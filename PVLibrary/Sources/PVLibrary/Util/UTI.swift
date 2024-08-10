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
