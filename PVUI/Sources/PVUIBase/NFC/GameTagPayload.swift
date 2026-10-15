//
//  GameTagPayload.swift
//  PVUIBase
//
//  The NDEF layout of a game tag, shared with iFly and iCube:
//    1. Well-Known URI record: the app's launch URL for the game.
//    2. Well-Known Text record ("en"): `app=<bundle id>;title=<game title>`.
//
//  Pure Foundation so it builds on every platform and tests run anywhere;
//  only GameTagWriter / GameTagReader touch CoreNFC.
//

import Foundation
import PVPrimitives

// MARK: - Raw record

/// One NDEF record in wire form, independent of CoreNFC's `NFCNDEFPayload`.
public struct GameTagRecord: Equatable, Sendable {
    /// NFC Forum Type Name Format values used here.
    public enum TypeNameFormat: UInt8, Sendable {
        case empty = 0x00
        case wellKnown = 0x01
        case media = 0x02
        case absoluteURI = 0x03
        case external = 0x04
        case unknown = 0x05
        case unchanged = 0x06
    }

    /// Raw TNF (3 bits). Kept raw so reserved values from other writers survive parsing.
    public var typeNameFormat: UInt8
    public var type: Data
    public var identifier: Data
    public var payload: Data

    public init(typeNameFormat: UInt8, type: Data, identifier: Data = Data(), payload: Data) {
        self.typeNameFormat = typeNameFormat
        self.type = type
        self.identifier = identifier
        self.payload = payload
    }

    /// Well-Known record type for URIs ("U").
    static let uriType = Data("U".utf8)
    /// Well-Known record type for text ("T").
    static let textType = Data("T".utf8)

    var isWellKnown: Bool { typeNameFormat == TypeNameFormat.wellKnown.rawValue }

    /// Bytes this record occupies inside an NDEF message.
    var encodedLength: Int {
        let flagsAndTypeLength = 2
        let payloadLengthField = payload.count <= NDEFLimits.shortRecordMaxPayload ? 1 : 4
        let identifierField = identifier.isEmpty ? 0 : 1 + identifier.count
        return flagsAndTypeLength + payloadLengthField + identifierField + type.count + payload.count
    }
}

private enum NDEFLimits {
    /// Largest payload a short record (SR flag, one length byte) can carry.
    static let shortRecordMaxPayload = 255
    /// Text record status byte: bit 7 set means UTF-16.
    static let textUTF16Flag: UInt8 = 0x80
    /// Text record status byte: low 6 bits hold the language code length.
    static let textLanguageLengthMask: UInt8 = 0x3F
}

// MARK: - URI record

enum NDEFURIRecord {
    /// NFC Forum URI RTD abbreviation table, indexed by identifier code (0x00–0x23).
    static let prefixes: [String] = [
        "", "http://www.", "https://www.", "http://", "https://", "tel:", "mailto:",
        "ftp://anonymous:anonymous@", "ftp://ftp.", "ftps://", "sftp://", "smb://", "nfs://",
        "ftp://", "dav://", "news:", "telnet://", "imap:", "rtsp://", "urn:", "pop:", "sip:",
        "sips:", "tftp:", "btspp://", "btl2cap://", "btgoep://", "tcpobex://", "irdaobex://",
        "file://", "urn:epc:id:", "urn:epc:tag:", "urn:epc:pat:", "urn:epc:raw:", "urn:epc:",
        "urn:nfc:"
    ]

    /// Encodes a URI with the longest matching abbreviation.
    static func record(for uri: String) -> GameTagRecord {
        var bestCode = 0
        for (code, prefix) in prefixes.enumerated()
        where !prefix.isEmpty && uri.hasPrefix(prefix) && prefix.count > prefixes[bestCode].count {
            bestCode = code
        }
        var payload = Data([UInt8(bestCode)])
        payload.append(Data(uri.dropFirst(prefixes[bestCode].count).utf8))
        return GameTagRecord(typeNameFormat: GameTagRecord.TypeNameFormat.wellKnown.rawValue,
                             type: GameTagRecord.uriType,
                             payload: payload)
    }

    /// Decodes a Well-Known URI record or an absolute-URI record; `nil` when malformed.
    static func uri(from record: GameTagRecord) -> String? {
        if record.typeNameFormat == GameTagRecord.TypeNameFormat.absoluteURI.rawValue {
            return String(data: record.type, encoding: .utf8)
        }
        guard record.isWellKnown, record.type == GameTagRecord.uriType,
              let code = record.payload.first, Int(code) < prefixes.count,
              let rest = String(data: record.payload.dropFirst(), encoding: .utf8) else { return nil }
        let uri = prefixes[Int(code)] + rest
        return uri.isEmpty ? nil : uri
    }
}

// MARK: - Text record

enum NDEFTextRecord {
    static func record(text: String, languageCode: String) -> GameTagRecord {
        let language = Data(languageCode.utf8)
        var payload = Data([UInt8(language.count) & NDEFLimits.textLanguageLengthMask])
        payload.append(language)
        payload.append(Data(text.utf8))
        return GameTagRecord(typeNameFormat: GameTagRecord.TypeNameFormat.wellKnown.rawValue,
                             type: GameTagRecord.textType,
                             payload: payload)
    }

    /// Decodes a Well-Known Text record; `nil` when malformed.
    static func text(from record: GameTagRecord) -> (languageCode: String, text: String)? {
        guard record.isWellKnown, record.type == GameTagRecord.textType,
              let status = record.payload.first else { return nil }
        let languageLength = Int(status & NDEFLimits.textLanguageLengthMask)
        let body = record.payload.dropFirst()
        guard languageLength <= body.count,
              let language = String(data: body.prefix(languageLength), encoding: .ascii) else { return nil }
        let textBytes = body.dropFirst(languageLength)
        let encoding: String.Encoding = (status & NDEFLimits.textUTF16Flag) != 0 ? .utf16 : .utf8
        guard let text = String(data: Data(textBytes), encoding: encoding) else { return nil }
        return (language, text)
    }
}

// MARK: - Sibling apps

/// Apps that write tags in the same format. A tag whose URI matches one of them is
/// reported as "belongs to <name>" instead of being treated as unreadable.
public struct GameTagSiblingApp: Equatable, Sendable {
    public let name: String
    /// URL schemes the app's launch URLs use (any host).
    public let schemes: Set<String>
    /// Universal-link hosts the app claims.
    public let hosts: Set<String>
    /// Bundle identifiers written in the text record's `app=` field.
    public let bundleIdentifiers: Set<String>

    /// The sibling table. One entry per app; update a row when an app's URL format changes.
    public static let all: [GameTagSiblingApp] = [
        GameTagSiblingApp(name: "iCube",
                          schemes: ["dolphinios", "icube"],
                          hosts: ["icube-emu.com"],
                          bundleIdentifiers: ["com.joemattiello.iCube"]),
        GameTagSiblingApp(name: "iFly",
                          schemes: ["ifly"],
                          hosts: ["ifly-emu.com"],
                          bundleIdentifiers: ["com.joemattiello.iFly"])
    ]

    static func matching(url: URL) -> GameTagSiblingApp? {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        return all.first { app in
            app.schemes.contains(scheme) || ((scheme == "https" || scheme == "http") && app.hosts.contains(host))
        }
    }

    static func matching(bundleIdentifier: String) -> GameTagSiblingApp? {
        all.first { $0.bundleIdentifiers.contains(bundleIdentifier) }
    }
}

// MARK: - What a tag holds

/// The result of reading a tag.
public enum GameTagContent: Equatable, Sendable {
    /// A Provenance game tag.
    case game(md5: String, title: String?)
    /// A tag written by another app. `name` is `nil` when the app is not a known sibling.
    case otherApp(name: String?)
    /// The tag has no NDEF records.
    case empty
    /// Records that are neither a game link nor another app's tag.
    case unrecognized

    /// Text for the NFC sheet when the tag can't open a game.
    public var failureMessage: String? {
        switch self {
        case .game:
            return nil
        case .otherApp(let name?):
            return "This tag belongs to \(name)."
        case .otherApp(nil):
            return "This tag belongs to another app."
        case .empty:
            return "This tag is empty. Write a game to it from the library."
        case .unrecognized:
            return "This tag doesn't hold a game link."
        }
    }
}

// MARK: - Payload

/// The two records Provenance writes for one game.
public struct GameTagPayload: Equatable, Sendable {
    /// Language code of the text record, fixed by the shared format.
    public static let textLanguageCode = "en"
    static let appKey = "app"
    static let titleKey = "title"
    static let fieldSeparator: Character = ";"

    public let launchURL: URL
    public let bundleIdentifier: String
    public let title: String

    public init(launchURL: URL, bundleIdentifier: String, title: String) {
        self.launchURL = launchURL
        self.bundleIdentifier = bundleIdentifier
        self.title = title
    }

    /// A payload for a library game. The URI is the universal link so background tag
    /// reading can launch the app.
    public init?(md5: String, title: String, bundleIdentifier: String) {
        guard ProvenanceDeepLink.isMD5(md5), let url = ProvenanceDeepLink.gameUniversalLink(md5) else { return nil }
        self.init(launchURL: url, bundleIdentifier: bundleIdentifier, title: title)
    }

    /// `app=<bundle id>;title=<title>`. The title comes last so a `;` inside it survives.
    static func textRecordText(bundleIdentifier: String, title: String) -> String {
        "\(appKey)=\(bundleIdentifier)\(fieldSeparator)\(titleKey)=\(title)"
    }

    public var records: [GameTagRecord] {
        [NDEFURIRecord.record(for: launchURL.absoluteString),
         NDEFTextRecord.record(text: Self.textRecordText(bundleIdentifier: bundleIdentifier, title: title),
                               languageCode: Self.textLanguageCode)]
    }

    /// Records that fit a tag holding at most `capacity` message bytes. The title is shortened
    /// first, then the text record dropped; `nil` when even the URI record alone does not fit.
    public func records(fittingCapacity capacity: Int) -> [GameTagRecord]? {
        let uri = NDEFURIRecord.record(for: launchURL.absoluteString)
        guard uri.encodedLength <= capacity else { return nil }

        func text(_ title: String) -> GameTagRecord {
            NDEFTextRecord.record(text: Self.textRecordText(bundleIdentifier: bundleIdentifier, title: title),
                                  languageCode: Self.textLanguageCode)
        }

        var title = Substring(self.title)
        while uri.encodedLength + text(String(title)).encodedLength > capacity {
            guard !title.isEmpty else { return [uri] }
            title = title.dropLast()
        }
        return [uri, text(String(title))]
    }

    /// Size of an NDEF message holding `records`.
    public static func encodedLength(of records: [GameTagRecord]) -> Int {
        records.reduce(0) { $0 + $1.encodedLength }
    }

    // MARK: Reading

    /// Classifies the records read from a tag. Ownership comes from the URI only; the text
    /// record's `app=` names a sibling app when the tag has no URI.
    public static func content(of records: [GameTagRecord]) -> GameTagContent {
        guard !records.isEmpty else { return .empty }
        let fields = records.lazy.compactMap { NDEFTextRecord.text(from: $0) }.first.map { textFields($0.text) }

        if let uri = records.lazy.compactMap({ NDEFURIRecord.uri(from: $0) }).first {
            guard let url = URL(string: uri) else { return .unrecognized }
            if let md5 = ProvenanceDeepLink.gameMD5(from: url) {
                return .game(md5: md5, title: fields?.title)
            }
            if isProvenance(url) { return .unrecognized }
            return .otherApp(name: GameTagSiblingApp.matching(url: url)?.name)
        }

        // No URI: a Provenance text record alone can't launch anything (and Lite/dev builds
        // write other bundle ids), so only a foreign `app=` turns into "another app".
        guard let app = fields?.app, !app.isEmpty, !app.hasPrefix(provenanceBundlePrefix) else { return .unrecognized }
        return .otherApp(name: GameTagSiblingApp.matching(bundleIdentifier: app)?.name)
    }

    /// Bundle id prefix shared by every Provenance build.
    static let provenanceBundlePrefix = "org.provenance-emu."

    /// Parses `app=<id>;title=<title>`. Unknown keys are ignored; `title` takes the rest of the string.
    static func textFields(_ text: String) -> (app: String?, title: String?) {
        var app: String?
        var title: String?
        var remainder = Substring(text)
        while !remainder.isEmpty {
            if remainder.hasPrefix("\(titleKey)=") {
                title = String(remainder.dropFirst(titleKey.count + 1))
                break
            }
            let field = remainder.prefix { $0 != fieldSeparator }
            if field.hasPrefix("\(appKey)=") {
                app = String(field.dropFirst(appKey.count + 1))
            }
            remainder = remainder.dropFirst(field.count).drop { $0 == fieldSeparator }
        }
        return (app, title)
    }

    private static func isProvenance(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        return scheme == ProvenanceDeepLink.scheme || ProvenanceDeepLink.universalLinkHosts.contains(host)
    }
}
