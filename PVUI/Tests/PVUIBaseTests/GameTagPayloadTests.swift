import Foundation
import Testing
@testable import PVUIBase

@Suite("NFC game tag payload")
struct GameTagPayloadTests {
    private let md5 = "0123456789ABCDEF0123456789ABCDEF"
    private let bundleID = "org.provenance-emu.provenance"
    /// Usable NDEF bytes on an NTAG213, the smallest common sticker.
    private let ntag213Capacity = 137

    private func payload(title: String = "Chrono Trigger") throws -> GameTagPayload {
        try #require(GameTagPayload(md5: md5, title: title, bundleIdentifier: bundleID))
    }

    private func uriRecord(_ uri: String) -> GameTagRecord {
        NDEFURIRecord.record(for: uri)
    }

    private func textRecord(_ text: String) -> GameTagRecord {
        NDEFTextRecord.record(text: text, languageCode: "en")
    }

    // MARK: Building

    @Test("URI record holds the universal link with the https:// abbreviation")
    func uriRecordBytes() throws {
        let records = try payload().records
        #expect(records.count == 2)
        let uri = records[0]
        #expect(uri.typeNameFormat == GameTagRecord.TypeNameFormat.wellKnown.rawValue)
        #expect(uri.type == Data("U".utf8))
        #expect(uri.payload.first == 0x04)
        #expect(String(data: uri.payload.dropFirst(), encoding: .utf8) == "provenance-emu.com/game/\(md5)")
        #expect(NDEFURIRecord.uri(from: uri) == "https://provenance-emu.com/game/\(md5)")
    }

    @Test("Text record is UTF-8, language en, app then title")
    func textRecordBytes() throws {
        let text = try payload().records[1]
        #expect(text.type == Data("T".utf8))
        #expect(text.payload.prefix(3) == Data([0x02]) + Data("en".utf8))
        #expect(String(data: text.payload.dropFirst(3), encoding: .utf8) == "app=\(bundleID);title=Chrono Trigger")
    }

    @Test("A malformed MD5 builds no payload")
    func rejectsBadMD5() {
        #expect(GameTagPayload(md5: "not-an-md5", title: "X", bundleIdentifier: bundleID) == nil)
    }

    // MARK: Round trip

    @Test("Written records read back as the same game")
    func roundTrip() throws {
        let content = GameTagPayload.content(of: try payload().records)
        #expect(content == .game(md5: md5, title: "Chrono Trigger"))
    }

    @Test("A title containing ; and = survives")
    func titleWithSeparators() throws {
        let title = "Zelda; Link=Hero"
        let content = GameTagPayload.content(of: try payload(title: title).records)
        #expect(content == .game(md5: md5, title: title))
    }

    @Test("A non-ASCII title survives")
    func unicodeTitle() throws {
        let title = "ポケットモンスター 赤"
        #expect(GameTagPayload.content(of: try payload(title: title).records) == .game(md5: md5, title: title))
    }

    @Test("The custom-scheme open route is accepted too", arguments: [
        "provenance://open?md5=0123456789ABCDEF0123456789ABCDEF",
        "https://provenance-emu.com/game/0123456789ABCDEF0123456789ABCDEF"
    ])
    func acceptsCurrentRoutes(_ uri: String) {
        let content = GameTagPayload.content(of: [uriRecord(uri)])
        #expect(content == .game(md5: md5, title: nil))
    }

    @Test("Text fields: unknown keys ignored, title takes the rest")
    func textFields() {
        let fields = GameTagPayload.textFields("v=2;app=com.example;title=A;B")
        #expect(fields.app == "com.example")
        #expect(fields.title == "A;B")
    }

    // MARK: Sibling apps

    @Test("Sibling and foreign URIs", arguments: [
        ("dolphinios://play?id=GALE01", "iCube"),
        ("icube://play?id=GALE01", "iCube"),
        ("https://icube-emu.com/play?id=GALE01", "iCube"),
        ("https://ifly-emu.com/play?md5=0123456789abcdef0123456789abcdef", "iFly"),
        ("ifly://open?id=foo", "iFly"),
        ("https://example.com/hello", nil),
        ("spotify:track:123", nil)
    ] as [(String, String?)])
    func otherApps(_ uri: String, _ name: String?) {
        let records = [uriRecord(uri), textRecord("app=com.example;title=Something")]
        #expect(GameTagPayload.content(of: records) == .otherApp(name: name))
    }

    @Test("A sibling text record without a URI names the app")
    func siblingTextOnly() {
        let content = GameTagPayload.content(of: [textRecord("app=com.joemattiello.iCube;title=Melee")])
        #expect(content == .otherApp(name: "iCube"))
    }

    @Test("Failure messages name the sibling")
    func failureMessages() {
        #expect(GameTagContent.otherApp(name: "iCube").failureMessage == "This tag belongs to iCube.")
        #expect(GameTagContent.otherApp(name: nil).failureMessage == "This tag belongs to another app.")
        #expect(GameTagContent.game(md5: md5, title: nil).failureMessage == nil)
    }

    // MARK: Malformed and unrelated tags

    @Test("No records is an empty tag")
    func emptyTag() {
        #expect(GameTagPayload.content(of: []) == .empty)
    }

    @Test("Provenance URLs that are not a game route are unrecognized", arguments: [
        "provenance://screen/library",
        "https://provenance-emu.com/skins/foo",
        "provenance://open?md5=short"
    ])
    func provenanceNonGame(_ uri: String) {
        #expect(GameTagPayload.content(of: [uriRecord(uri)]) == .unrecognized)
    }

    @Test("A Provenance text record alone is unrecognized")
    func ownTextOnly() {
        #expect(GameTagPayload.content(of: [textRecord("app=\(bundleID).lite;title=X")]) == .unrecognized)
    }

    @Test("Reserved URI prefix code is rejected")
    func reservedPrefixCode() {
        let record = GameTagRecord(typeNameFormat: 0x01, type: Data("U".utf8), payload: Data([0x24]) + Data("x".utf8))
        #expect(NDEFURIRecord.uri(from: record) == nil)
        #expect(GameTagPayload.content(of: [record]) == .unrecognized)
    }

    @Test("Empty URI payload is rejected")
    func emptyURIPayload() {
        let record = GameTagRecord(typeNameFormat: 0x01, type: Data("U".utf8), payload: Data())
        #expect(NDEFURIRecord.uri(from: record) == nil)
    }

    @Test("Text language length past the payload is rejected")
    func textLanguageOverrun() {
        let record = GameTagRecord(typeNameFormat: 0x01, type: Data("T".utf8), payload: Data([0x3F]) + Data("en".utf8))
        #expect(NDEFTextRecord.text(from: record) == nil)
    }

    @Test("A broken text record doesn't hide a good URI")
    func brokenTextRecord() {
        let broken = GameTagRecord(typeNameFormat: 0x01, type: Data("T".utf8), payload: Data([0x3F]))
        let uri = uriRecord("https://provenance-emu.com/game/\(md5)")
        #expect(GameTagPayload.content(of: [broken, uri]) == .game(md5: md5, title: nil))
    }

    @Test("Other writers' encodings decode")
    func otherWriterEncodings() throws {
        // https://www. abbreviation (0x02).
        let www = GameTagRecord(typeNameFormat: 0x01, type: Data("U".utf8), payload: Data([0x02]) + Data("example.com".utf8))
        #expect(NDEFURIRecord.uri(from: www) == "https://www.example.com")
        // Absolute-URI TNF keeps the URI in the type field.
        let absolute = GameTagRecord(typeNameFormat: 0x03, type: Data("dolphinios://play?id=GALE01".utf8), payload: Data())
        #expect(GameTagPayload.content(of: [absolute]) == .otherApp(name: "iCube"))
        // UTF-16 text record (status bit 7).
        let utf16 = try #require("app=com.joemattiello.iCube;title=Melee".data(using: .utf16))
        let text = GameTagRecord(typeNameFormat: 0x01, type: Data("T".utf8), payload: Data([0x82]) + Data("en".utf8) + utf16)
        #expect(NDEFTextRecord.text(from: text)?.text == "app=com.joemattiello.iCube;title=Melee")
    }

    // MARK: Capacity

    @Test("Long titles are shortened to fit a small tag")
    func fitsSmallTag() throws {
        let title = String(repeating: "Very Long Game Title ", count: 10)
        let records = try #require(try payload(title: title).records(fittingCapacity: ntag213Capacity))
        #expect(records.count == 2)
        #expect(GameTagPayload.encodedLength(of: records) <= ntag213Capacity)
        guard case let .game(readMD5, readTitle?) = GameTagPayload.content(of: records) else {
            Issue.record("expected a game")
            return
        }
        #expect(readMD5 == md5)
        #expect(!readTitle.isEmpty)
        #expect(title.hasPrefix(readTitle))
    }

    @Test("Short titles are written whole")
    func shortTitleUnchanged() throws {
        let payload = try payload()
        #expect(payload.records(fittingCapacity: ntag213Capacity) == payload.records)
    }

    @Test("Without room for the text record only the URI is written")
    func uriOnly() throws {
        let payload = try payload()
        let uriLength = payload.records[0].encodedLength
        #expect(payload.records(fittingCapacity: uriLength) == [payload.records[0]])
    }

    @Test("A tag too small for the URI gets nothing")
    func tooSmall() throws {
        let payload = try payload()
        #expect(payload.records(fittingCapacity: payload.records[0].encodedLength - 1) == nil)
    }

    @Test("Record length counts the header bytes")
    func encodedLength() throws {
        let uri = try payload().records[0]
        // flags + type length + 1-byte payload length + "U"
        #expect(uri.encodedLength == 4 + uri.payload.count)
    }
}
