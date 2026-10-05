//
//  PPSSPPAdhocTests.swift
//  PVLibRetroTests
//
//  PPSSPP ad hoc netplay is driven through core options. These cover the pure
//  parts: how an IP becomes the core's twelve address digits, which options a
//  host and a client set, which LAN address is chosen, and when a running game
//  has to restart.
//

import Testing
import Foundation
@testable import PVCoreBridgeRetro

@Suite("PPSSPP ad hoc options")
struct PPSSPPAdhocTests {

    private func value(_ key: String, in values: [(key: String, value: String)]) -> String? {
        values.first { $0.key == key }?.value
    }

    // MARK: Address digits

    @Test("An IP becomes three zero-padded digits per octet")
    func addressDigits() {
        #expect(PPSSPPAdhocOptions.addressDigits(forIPv4: "192.168.1.7") == "192168001007")
        #expect(PPSSPPAdhocOptions.addressDigits(forIPv4: "10.0.0.1") == "010000000001")
        #expect(PPSSPPAdhocOptions.addressDigits(forIPv4: "255.255.255.255") == "255255255255")
    }

    @Test("Anything that is not a dotted-quad IPv4 address has no digits")
    func addressDigitsRejectsNonIPv4() {
        let bad = ["", "localhost", "192.168.1", "192.168.1.7.5", "256.1.1.1", "1.1.1.-1", "a.b.c.d", "1..1.1", "1.1.1.1234", "fe80::1", "٣.٣.٣.٣"]
        for text in bad {
            #expect(PPSSPPAdhocOptions.addressDigits(forIPv4: text) == nil, "\(text)")
        }
    }

    @Test("The digit option keys run 01 to 12")
    func digitKeys() {
        let keys = PPSSPPAdhocOptions.serverAddressDigitKeys
        #expect(keys.count == 12)
        #expect(keys.first == "ppsspp_pro_ad_hoc_server_address01")
        #expect(keys.last == "ppsspp_pro_ad_hoc_server_address12")
        #expect(PPSSPPAdhocOptions.macNibbleKeys.first == "ppsspp_change_mac_address01")
        #expect(PPSSPPAdhocOptions.macNibbleKeys.last == "ppsspp_change_mac_address12")
    }

    // MARK: Option sets

    @Test("A host runs the built-in server and points at itself")
    func hostValues() throws {
        let values = try #require(PPSSPPAdhocOptions.values(isHost: true, serverIPv4: "192.168.1.7"))
        #expect(value("ppsspp_enable_wlan", in: values) == "enabled")
        #expect(value("ppsspp_enable_builtin_pro_ad_hoc_server", in: values) == "enabled")
        #expect(value("ppsspp_change_pro_ad_hoc_server_address", in: values) == "IP address")
        #expect(value("ppsspp_port_offset", in: values) == "10000")
        #expect(value("ppsspp_enable_upnp", in: values) == "disabled")
        let digits = PPSSPPAdhocOptions.serverAddressDigitKeys.compactMap { value($0, in: values) }
        #expect(digits.joined() == "192168001007")
    }

    @Test("A client points at the host and runs no server")
    func clientValues() throws {
        let values = try #require(PPSSPPAdhocOptions.values(isHost: false, serverIPv4: "10.0.0.42"))
        #expect(value("ppsspp_enable_wlan", in: values) == "enabled")
        #expect(value("ppsspp_enable_builtin_pro_ad_hoc_server", in: values) == "disabled")
        #expect(value("ppsspp_port_offset", in: values) == "10000")
        let digits = PPSSPPAdhocOptions.serverAddressDigitKeys.compactMap { value($0, in: values) }
        #expect(digits.joined() == "010000000042")
    }

    @Test("A session never sets the MAC options")
    func macOptionsUntouched() throws {
        let values = try #require(PPSSPPAdhocOptions.values(isHost: true, serverIPv4: "192.168.1.7"))
        for key in PPSSPPAdhocOptions.macNibbleKeys {
            #expect(value(key, in: values) == nil)
        }
        #expect(values.count == 5 + 12)
    }

    @Test("A non-IPv4 server builds no option set")
    func valuesRejectsBadAddress() {
        #expect(PPSSPPAdhocOptions.values(isHost: true, serverIPv4: "host.local") == nil)
    }

    @Test("Every option value is one the core offers")
    func valuesFitTheCoreChoices() throws {
        func definition(_ key: String, _ choices: [String]) -> ThinCoreOptionDefinition {
            ThinCoreOptionDefinition(key: key, title: key, defaultValue: choices[0], choices: choices.map { .init(value: $0, label: $0) })
        }
        let digits = (0...9).map(String.init)
        var definitions = [
            definition("ppsspp_enable_wlan", ["disabled", "enabled"]),
            definition("ppsspp_enable_builtin_pro_ad_hoc_server", ["disabled", "enabled"]),
            definition("ppsspp_change_pro_ad_hoc_server_address", ["socom.cc", "localhost", "IP address"]),
            definition("ppsspp_port_offset", ["0", "1000", "10000", "20000"]),
            definition("ppsspp_enable_upnp", ["disabled", "enabled"])
        ]
        definitions += PPSSPPAdhocOptions.serverAddressDigitKeys.map { definition($0, digits) }
        let byKey = Dictionary(uniqueKeysWithValues: definitions.map { ($0.key, $0) })
        let values = try #require(PPSSPPAdhocOptions.values(isHost: true, serverIPv4: "172.16.254.3"))
        for (key, raw) in values {
            #expect(byKey[key]?.rawValue(forStored: raw) == raw, "\(key)=\(raw)")
        }
    }

    // MARK: Stored representation

    @Test("The options UI stores a Bool for a switch and the label for a choice")
    func storedRepresentation() {
        let toggle = ThinCoreOptionDefinition(
            key: "ppsspp_enable_wlan", title: "wlan", defaultValue: "disabled",
            choices: [.init(value: "disabled", label: "disabled"), .init(value: "enabled", label: "enabled")]
        )
        #expect(toggle.storedRepresentation(forRaw: "enabled") as? Bool == true)
        #expect(toggle.storedRepresentation(forRaw: "disabled") as? Bool == false)

        let choice = ThinCoreOptionDefinition(
            key: "ppsspp_port_offset", title: "offset", defaultValue: "0",
            choices: [.init(value: "0", label: "0"), .init(value: "10000", label: "10000 (netplay)")]
        )
        #expect(choice.storedRepresentation(forRaw: "10000") as? String == "10000 (netplay)")
        #expect(choice.rawValue(forStored: choice.storedRepresentation(forRaw: "10000")) == "10000")
    }

    // MARK: LAN address choice

    @Test("The Wi-Fi range wins over cellular, VPN and other private ranges")
    func preferredLANAddress() {
        let all = ["100.64.3.9", "10.8.0.2", "172.20.1.5", "192.168.1.7", "2001:db8::1"]
        #expect(PPSSPPAdhocOptions.preferredLANAddress(from: all) == "192.168.1.7")
        #expect(PPSSPPAdhocOptions.preferredLANAddress(from: ["10.8.0.2", "172.20.1.5"]) == "172.20.1.5")
        #expect(PPSSPPAdhocOptions.preferredLANAddress(from: ["10.8.0.2"]) == "10.8.0.2")
    }

    @Test("A device with no private IPv4 address has none to host on")
    func preferredLANAddressNone() {
        #expect(PPSSPPAdhocOptions.preferredLANAddress(from: []) == nil)
        #expect(PPSSPPAdhocOptions.preferredLANAddress(from: ["100.64.3.9", "172.32.0.1", "2001:db8::1"]) == nil)
    }

    @Test("Loopback addresses are rejected as servers")
    func loopback() {
        #expect(PPSSPPAdhocOptions.isLoopback("127.0.0.1"))
        #expect(PPSSPPAdhocOptions.isLoopback("127.1.2.3"))
        #expect(PPSSPPAdhocOptions.isLoopback("localhost"))
        #expect(PPSSPPAdhocOptions.isLoopback("LocalHost"))
        #expect(PPSSPPAdhocOptions.isLoopback("  127.0.0.1 "))
        #expect(PPSSPPAdhocOptions.isLoopback(" localhost\n"))
        #expect(!PPSSPPAdhocOptions.isLoopback("192.168.1.7"))
    }

    // MARK: Restart

    @Test("A host always restarts")
    func hostRestarts() {
        #expect(PPSSPPAdhocOptions.needsRestart(isHost: true, currentOptions: ["ppsspp_port_offset": "10000"]))
    }

    @Test("A client restarts only when boot-only settings differ")
    func clientRestart() {
        #expect(!PPSSPPAdhocOptions.needsRestart(isHost: false, currentOptions: ["ppsspp_port_offset": "10000"]))
        #expect(PPSSPPAdhocOptions.needsRestart(isHost: false, currentOptions: ["ppsspp_port_offset": "0"]))
        #expect(PPSSPPAdhocOptions.needsRestart(isHost: false, currentOptions: [
            "ppsspp_port_offset": "10000", "ppsspp_change_pro_ad_hoc_server_address": "localhost"
        ]))
        #expect(!PPSSPPAdhocOptions.needsRestart(isHost: false, currentOptions: [
            "ppsspp_port_offset": "10000", "ppsspp_change_pro_ad_hoc_server_address": "socom.cc"
        ]))
    }

    // MARK: Backup of saved options

    @Test("Stopping restores what was saved and removes what was not")
    func backupRoundTrip() throws {
        let md5 = "test-ppsspp-\(UUID().uuidString)"
        let defaults = UserDefaults.standard
        let prefix = "PVThinLibretroCore.\(md5)."
        let kept = prefix + "ppsspp_port_offset"
        let added = prefix + "ppsspp_enable_wlan"
        defer {
            for key in [kept, added, PVThinLibretroCore.adhocBackupKey(md5: md5)] { defaults.removeObject(forKey: key) }
        }
        defaults.set("20000", forKey: kept)

        let backupKey = PVThinLibretroCore.adhocBackupKey(md5: md5)
        defaults.set(["present": [kept: "20000"], "absent": [added]] as [String: Any], forKey: backupKey)
        defaults.set("10000", forKey: kept)
        defaults.set(true, forKey: added)

        PVThinLibretroCore.restoreAdhocBackup(md5: md5)

        #expect(defaults.string(forKey: kept) == "20000")
        #expect(defaults.object(forKey: added) == nil)
        #expect(defaults.dictionary(forKey: backupKey) == nil)
    }

    @Test("The session messages name the address and tell the player what to do next")
    func sessionMessages() {
        let host = PVThinLibretroCore.ppssppSessionMessage(isHost: true, address: "192.168.1.7", restarting: true, paused: true)
        #expect(host.contains("192.168.1.7"))
        #expect(host.contains("restarts when you resume"))
        #expect(host.contains("Ad Hoc"))
        let client = PVThinLibretroCore.ppssppSessionMessage(isHost: false, address: "192.168.1.7", restarting: false, paused: false)
        #expect(!client.contains("restart"))
        #expect(client.contains("join"))
    }
}
