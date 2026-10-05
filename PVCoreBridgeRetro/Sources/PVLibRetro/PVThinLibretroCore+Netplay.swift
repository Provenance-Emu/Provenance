//
//  PVThinLibretroCore+Netplay.swift
//  PVCoreBridgeRetro
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Netplay for thin libretro cores that implement the netpacket interface
//  (RETRO_ENVIRONMENT_SET_NETPACKET_INTERFACE, env 78), such as gpSP (GBA
//  link cable) and melonDS DS (DS local wireless). The core exchanges its
//  own packets with other players; PVNetplay's NetpacketTransport carries
//  them, and PVThinLibretroFrontend hands them to the core on the emulation
//  thread.
//
//  PPSSPP has no netpacket interface: it opens its own sockets for PSP ad hoc
//  play. Its netplay is driven entirely through core options (see "PPSSPP ad
//  hoc" below): the host runs PPSSPP's built-in PRO ad hoc server, the client
//  points at the host's IP, and the game restarts so the boot-only options
//  take effect.
//
//  Other cores without the interface have no netplay on the thin wrapper:
//  RetroArch's rollback netplay needs the RetroArch runtime.
//

import Combine
import Foundation
import PVCoreBridge
import PVCoreObjCBridge
import PVEmulatorCore
import PVLogging
import PVNetplay

// MARK: - PVNetpacketCapable conformance

extension PVThinLibretroCore: PVNetpacketCapable {

    /// Whether the loaded core registered a netpacket callback via env 78.
    var hasNetpacketInterface: Bool {
        _bridge.hasNetpacketInterface
    }

    /// The protocol_version string from the core's callback, or nil.
    var netpacketProtocolVersion: String? {
        _bridge.netpacketProtocolVersion
    }
}

// MARK: - PVNetplayCapable conformance

extension PVThinLibretroCore: PVNetplayCapable {

    /// Netplay is supported when the core registered a netpacket callback, or
    /// it is PPSSPP, whose ad hoc mode is driven by core options.
    var supportsNetplay: Bool {
        hasNetpacketInterface || isPPSSPPAdhocCore
    }

    /// Human-readable name of the netplay engine powering this core.
    var netplayEngineName: String { isPPSSPPAdhocCore ? "PPSSPP AdHoc" : "Netpacket" }

    /// PPSSPP reads its ad hoc server and port offset only when the game boots.
    var netplayHostingRestartsGame: Bool { isPPSSPPAdhocCore }

    /// Start hosting or join a host. Netpacket sessions have players only, so
    /// spectating is unsupported.
    func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        if isPPSSPPAdhocCore {
            try startPPSSPPAdhoc(role: role, settings: settings)
            return
        }
        guard hasNetpacketInterface else { throw NetplayError.unsupported }
        guard _netpacketTransport == nil else { throw NetplayError.alreadyActive }

        let transportRole: NetpacketTransport.Role
        switch role {
        case .host(let port):
            transportRole = .host(port: port)
        case .client(let host, let port):
            transportRole = .client(host: host, port: port)
        case .spectator:
            throw NetplayError.invalidSettings("This game can't be watched as a spectator. Join as a player instead.")
        }

        let transport = NetpacketTransport(
            role: transportRole,
            protocolVersion: netpacketCompatibilityVersion,
            maxClients: max(settings.maxPlayers - 1, 1)
        )
        _netpacketTransport = transport
        let bridge = _bridge
        let room = makeNetplayRoom(role: role, settings: settings)
        if case .host = transportRole {
            transport.bonjourAdvertisement = (
                name: Self.bonjourInstanceName("\(room.hostName) — \(room.gameName)"),
                txtRecord: [
                    "sessionId": room.id.uuidString,
                    "nickname": room.hostName,
                    "game": room.gameName,
                    "core": room.coreIdentifier,
                    "maxPlayers": String(room.maxPlayers),
                    "allowSpectators": "0"
                ]
            )
        }

        transport.onPacket = { data, clientID in
            bridge.enqueueNetpacketData(data, fromClient: clientID)
        }
        // A client starts the core as soon as the host assigns its ID, before
        // the transport delivers the first packet, so none is dropped.
        transport.onWelcomed = { clientID in
            ILOG("ThinCore netplay: joined as client \(clientID)")
            bridge.startNetpacketSession(withClientID: clientID)
        }
        transport.onPeerConnected = { [weak self, weak transport] clientID in
            bridge.netpacketPeerConnected(clientID)
            self?.publishHostedRoom(room, peerCount: transport?.connectedPeerIDs.count ?? 0)
        }
        transport.onPeerDisconnected = { [weak self, weak transport] clientID in
            bridge.netpacketPeerDisconnected(clientID)
            self?.publishHostedRoom(room, peerCount: transport?.connectedPeerIDs.count ?? 0)
        }
        transport.onSessionEnded = { [weak self] error in
            WLOG("ThinCore netplay: session ended — \(error.localizedDescription)")
            self?.endNetplaySession(reason: error == .hostClosed ? .hostClosed : .networkError)
        }
        bridge.netpacketSendBlock = { [weak transport] flags, buf, len, clientID in
            guard let transport else { return }
            transport.send(data: Data(bytes: buf, count: len), to: clientID, flags: flags)
        }
        bridge.netpacketRejectPeerBlock = { [weak transport] clientID in
            transport?.disconnectPeer(clientID)
        }

        // The host is client 0 and starts before anyone can connect, so the
        // core sees `start` before any `connected`. A client only learns its
        // ID from the host's welcome.
        if case .host = transportRole {
            bridge.startNetpacketSession(withClientID: NetpacketTransport.hostID)
        }

        do {
            try await transport.start()
        } catch {
            endNetplaySession(reason: nil)
            throw NetplayError.connectionFailed(error.localizedDescription)
        }

        switch transportRole {
        case .host:
            publishHostedRoom(room, peerCount: 0)
        case .client:
            updateNetplayState(.connected(session: NetplaySession(
                room: room,
                role: role,
                peers: [],
                frameDelay: 0,
                isRollbackEnabled: false
            )))
        }
    }

    /// Stop the active netplay session.
    func stopNetplay() async {
        if _ppssppAdhocSession != nil {
            stopPPSSPPAdhoc()
            return
        }
        endNetplaySession(reason: nil)
    }

    /// The current netplay state.
    var netplayState: NetplayState {
        _netplayStateSubject.value
    }

    #if canImport(Combine)
    /// Publisher for netplay state changes.
    var netplayStatePublisher: AnyPublisher<NetplayState, Never> {
        _netplayStateSubject.eraseToAnyPublisher()
    }
    #endif
}

// MARK: - Session helpers

extension PVThinLibretroCore {

    /// What peers must agree on: the core's netpacket protocol version, or
    /// its name and version when it doesn't declare one (as RetroArch does).
    var netpacketCompatibilityVersion: String {
        if let version = netpacketProtocolVersion, !version.isEmpty {
            return version
        }
        let info = _bridge.systemInfo
        return "\(Self.string(fromCField: info.library_name)) \(Self.string(fromCField: info.library_version))"
    }

    /// `name` cut to Bonjour's 63-byte instance-name limit without splitting a character.
    static func bonjourInstanceName(_ name: String) -> String {
        var result = ""
        for character in name {
            guard result.utf8.count + String(character).utf8.count <= 63 else { break }
            result.append(character)
        }
        return result
    }

    /// A NUL-terminated C `char[N]` field (imported as a tuple) as a String.
    private static func string<T>(fromCField field: T) -> String {
        withUnsafeBytes(of: field) { bytes in
            String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8) ?? ""
        }
    }

    /// Tears the session down: no transport callback fires after this, and the
    /// core gets `stop` on its next frame (or when emulation stops).
    func endNetplaySession(reason: DisconnectReason?) {
        _netpacketTransport?.stop()
        _netpacketTransport = nil
        _bridge.stopNetpacketSession()
        _bridge.netpacketSendBlock = nil
        _bridge.netpacketRejectPeerBlock = nil
        updateNetplayState(reason.map { .disconnected(reason: $0) } ?? .idle)
    }

    private func makeNetplayRoom(role: NetplayRole, settings: NetplaySettings) -> NetplayRoom {
        let gameName = _bridge.romPath.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent } ?? ""
        let (address, port): (String, UInt16)
        switch role {
        case .host(let hostPort): (address, port) = ("0.0.0.0", hostPort)
        case .client(let host, let hostPort), .spectator(let host, let hostPort): (address, port) = (host, hostPort)
        }
        return NetplayRoom(
            hostName: settings.nickname.isEmpty ? "Provenance" : settings.nickname,
            gameName: gameName,
            gameHash: "",
            coreIdentifier: coreIdentifier ?? "",
            maxPlayers: settings.maxPlayers,
            currentPlayers: 1,
            isLAN: true,
            hostAddress: address,
            port: port,
            allowsSpectators: false,
            discoverySource: .netpacket
        )
    }

    private func publishHostedRoom(_ room: NetplayRoom, peerCount: Int) {
        updateNetplayState(.hosting(room: NetplayRoom(
            id: room.id,
            hostName: room.hostName,
            gameName: room.gameName,
            gameHash: room.gameHash,
            coreIdentifier: room.coreIdentifier,
            maxPlayers: room.maxPlayers,
            currentPlayers: 1 + peerCount,
            isLAN: room.isLAN,
            hostAddress: room.hostAddress,
            // The bound port, which differs from the requested one when that was 0.
            port: _netpacketTransport?.listeningPort ?? room.port,
            allowsSpectators: false,
            discoverySource: .netpacket
        )))
    }
}

// MARK: - Backing storage

extension PVThinLibretroCore {

    /// The active netpacket transport, or nil when no session is running.
    var _netpacketTransport: NetpacketTransport? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.transport) as? NetpacketTransport }
        set { objc_setAssociatedObject(self, &AssociatedKeys.transport, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// Combine subject for netplay state updates (also serves as source of truth).
    /// Created under a lock: the manager actor and the main thread can both
    /// reach it first.
    var _netplayStateSubject: CurrentValueSubject<NetplayState, Never> {
        AssociatedKeys.stateSubjectLock.lock()
        defer { AssociatedKeys.stateSubjectLock.unlock() }
        if let existing = objc_getAssociatedObject(self, &AssociatedKeys.stateSubject)
            as? CurrentValueSubject<NetplayState, Never> {
            return existing
        }
        let subject = CurrentValueSubject<NetplayState, Never>(.idle)
        objc_setAssociatedObject(self, &AssociatedKeys.stateSubject, subject, .OBJC_ASSOCIATION_RETAIN)
        return subject
    }

    /// Publish a netplay state change.
    func updateNetplayState(_ state: NetplayState) {
        _netplayStateSubject.send(state)
    }
}

// MARK: - Private helpers

/// Associated object keys for netplay state stored on PVThinLibretroCore.
private enum AssociatedKeys {
    nonisolated(unsafe) static var transport = 0
    nonisolated(unsafe) static var stateSubject = 0
    nonisolated(unsafe) static var ppssppSession = 0
    nonisolated(unsafe) static var ppssppDetected = 0
    static let stateSubjectLock = NSLock()
}

// MARK: - PPSSPP ad hoc

/// The core options that drive PPSSPP's ad hoc mode, and the pure functions
/// that build their values. See `Cores/PPSSPP/libretro_ppsspp/libretro/libretro_core_options.h`.
enum PPSSPPAdhocOptions {

    static let enableWlanKey = "ppsspp_enable_wlan"
    static let builtinServerKey = "ppsspp_enable_builtin_pro_ad_hoc_server"
    static let serverChoiceKey = "ppsspp_change_pro_ad_hoc_server_address"
    static let portOffsetKey = "ppsspp_port_offset"
    static let upnpKey = "ppsspp_enable_upnp"
    private static let serverAddressDigitKeyPrefix = "ppsspp_pro_ad_hoc_server_address"
    private static let macNibbleKeyPrefix = "ppsspp_change_mac_address"

    /// The server choice that makes the core use the twelve address-digit options.
    static let serverChoiceIPAddress = "IP address"
    /// The server choice that puts PPSSPP into single-machine (loopback) mode.
    static let serverChoiceLocalhost = "localhost"
    /// Every device in a session must use the same port offset.
    static let portOffset = "10000"
    /// The PRO ad hoc server's fixed TCP port.
    static let serverPort: UInt16 = 27312

    private static let digitCount = 12
    private static let macNibbleCount = 12
    private static let octetCount = 4
    private static let maxOctet = 255
    private static let maxOctetDigits = 3

    /// `ppsspp_pro_ad_hoc_server_address01` … `12`: one decimal digit each.
    static let serverAddressDigitKeys: [String] = (1...digitCount).map {
        serverAddressDigitKeyPrefix + String(format: "%02d", $0)
    }

    /// `ppsspp_change_mac_address01` … `12`: one hex nibble each.
    static let macNibbleKeys: [String] = (1...macNibbleCount).map {
        macNibbleKeyPrefix + String(format: "%02d", $0)
    }

    /// The four octets of a dotted-quad IPv4 address, or nil when `text` is not one.
    static func octets(of text: String) -> [Int]? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == octetCount else { return nil }
        let values = parts.compactMap { part -> Int? in
            guard !part.isEmpty, part.count <= maxOctetDigits, part.allSatisfy(\.isASCII), part.allSatisfy(\.isNumber) else {
                return nil
            }
            return Int(part)
        }
        guard values.count == octetCount, values.allSatisfy({ (0...maxOctet).contains($0) }) else { return nil }
        return values
    }

    /// An IPv4 address as the core's twelve digits, three per octet, zero padded:
    /// `192.168.1.7` → `"192168001007"`. Nil when `address` is not IPv4.
    static func addressDigits(forIPv4 address: String) -> String? {
        guard let octets = octets(of: address) else { return nil }
        return octets.map { String(format: "%03d", $0) }.joined()
    }

    /// A loopback address (or "localhost") puts PPSSPP in single-machine mode,
    /// where every socket binds to loopback and no other device can connect.
    static func isLoopback(_ address: String) -> Bool {
        // InitLocalhostIP strips spaces before testing.
        let stripped = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return stripped == serverChoiceLocalhost || stripped.hasPrefix("127.")
    }

    /// The best private IPv4 address in `addresses`, or nil when there is none.
    /// The device may also list cellular and VPN interfaces, so prefer the
    /// common home-router ranges: 192.168/16, then 172.16/12, then 10/8.
    static func preferredLANAddress(from addresses: [String]) -> String? {
        func rank(_ address: String) -> Int? {
            guard let o = octets(of: address) else { return nil }
            if o[0] == 192 && o[1] == 168 { return 0 }
            if o[0] == 172 && (16...31).contains(o[1]) { return 1 }
            if o[0] == 10 { return 2 }
            return nil
        }
        return (0...2).lazy.compactMap { wanted in addresses.first { rank($0) == wanted } }.first
    }

    /// The option values a session needs, in the core's raw strings.
    ///
    /// The host runs the built-in server and points at itself; a client points
    /// at the host and runs none. Both use the same port offset, and UPnP is
    /// off: it would try to open router ports for a LAN game. The MAC options
    /// are left out on purpose: all zeros makes the core pick a random MAC at
    /// every boot, which is unique per device.
    static func values(isHost: Bool, serverIPv4: String) -> [(key: String, value: String)]? {
        guard let digits = addressDigits(forIPv4: serverIPv4) else { return nil }
        var result: [(key: String, value: String)] = [
            (enableWlanKey, "enabled"),
            (builtinServerKey, isHost ? "enabled" : "disabled"),
            (serverChoiceKey, serverChoiceIPAddress),
            (portOffsetKey, portOffset),
            (upnpKey, "disabled")
        ]
        for (key, digit) in zip(serverAddressDigitKeys, digits) {
            result.append((key, String(digit)))
        }
        return result
    }

    /// Whether a running game must restart to pick the session up.
    ///
    /// The built-in server and the port offset are read only at boot. A host
    /// always restarts: whether the running game booted with the server on is
    /// not knowable from here. A client restarts only when the game booted with
    /// another port offset or in single-machine mode.
    static func needsRestart(isHost: Bool, currentOptions: [String: String]) -> Bool {
        if isHost { return true }
        if let offset = currentOptions[portOffsetKey], offset != portOffset { return true }
        return currentOptions[serverChoiceKey] == serverChoiceLocalhost
    }
}

extension ThinCoreOptionDefinition {

    /// What the options UI stores for `raw`: a Bool for an on/off switch, the
    /// choice's label otherwise. `rawValue(forStored:)` maps either back.
    func storedRepresentation(forRaw raw: String) -> Any {
        if toggleValues != nil { return isOn(raw) }
        return choices.first { $0.value == raw }?.label ?? raw
    }
}

/// One running PPSSPP ad hoc session on a thin core.
final class PPSSPPAdhocSession: @unchecked Sendable {
    let role: NetplayRole
    let room: NetplayRoom
    /// The game the persisted options belong to; nil when it has no MD5, in
    /// which case nothing was persisted.
    let md5: String?
    /// What the core held before, per option key, so stopping can put it back.
    let previousLiveValues: [String: String]

    init(role: NetplayRole, room: NetplayRoom, md5: String?, previousLiveValues: [String: String]) {
        self.role = role
        self.room = room
        self.md5 = md5
        self.previousLiveValues = previousLiveValues
    }
}

extension PVThinLibretroCore {

    /// Whether the loaded core is PPSSPP, recognised by the ad hoc options it
    /// declares rather than by name (any build of it carries them).
    var isPPSSPPAdhocCore: Bool {
        if let cached = objc_getAssociatedObject(self, &AssociatedKeys.ppssppDetected) as? NSNumber {
            return cached.boolValue
        }
        let definitions = _bridge.coreOptionDefinitions
        // Options are declared during core init; before that the answer is unknown.
        guard !definitions.isEmpty else { return false }
        let found = definitions.contains { ($0["key"] as? String) == PPSSPPAdhocOptions.enableWlanKey }
        objc_setAssociatedObject(self, &AssociatedKeys.ppssppDetected, NSNumber(value: found), .OBJC_ASSOCIATION_RETAIN)
        return found
    }

    var _ppssppAdhocSession: PPSSPPAdhocSession? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.ppssppSession) as? PPSSPPAdhocSession }
        set { objc_setAssociatedObject(self, &AssociatedKeys.ppssppSession, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    private static let ppssppSessionMessageDuration: TimeInterval = 8

    /// Start hosting or joining a PSP ad hoc session by driving the core's options.
    func startPPSSPPAdhoc(role: NetplayRole, settings: NetplaySettings) throws {
        guard _ppssppAdhocSession == nil else { throw NetplayError.alreadyActive }

        // Who the core connects to, and whether this device runs the server.
        let isHost: Bool
        let serverIPv4: String
        switch role {
        case .host:
            if let relay = settings.relayServer?.trimmingCharacters(in: .whitespaces), !relay.isEmpty {
                // An external server: this device joins like a client.
                guard PPSSPPAdhocOptions.octets(of: relay) != nil else {
                    throw NetplayError.invalidSettings("PPSSPP takes an ad hoc server as an IP address, such as 192.168.1.20.")
                }
                isHost = false
                serverIPv4 = relay
            } else {
                guard let lan = PPSSPPAdhocOptions.preferredLANAddress(from: NetplayLocalAddresses.current()) else {
                    throw NetplayError.invalidSettings("Connect to a Wi-Fi network to host.")
                }
                isHost = true
                serverIPv4 = lan
            }
        case .client(let host, _), .spectator(let host, _):
            // PPSSPP has no spectator concept — join as a regular client.
            let trimmed = host.trimmingCharacters(in: .whitespaces)
            guard PPSSPPAdhocOptions.octets(of: trimmed) != nil else {
                throw NetplayError.invalidSettings("Enter the host's IP address, such as 192.168.1.20.")
            }
            isHost = false
            serverIPv4 = trimmed
        }
        guard !PPSSPPAdhocOptions.isLoopback(serverIPv4) else {
            throw NetplayError.invalidSettings("A loopback address only works on one device. Use the host's Wi-Fi address.")
        }
        guard let values = PPSSPPAdhocOptions.values(isHost: isHost, serverIPv4: serverIPv4) else {
            throw NetplayError.invalidSettings("\(serverIPv4) is not an IPv4 address.")
        }

        // Every option must exist, and accept its value, in this build of the core.
        let definitions = Dictionary(
            _bridge.coreOptionDefinitions.compactMap(ThinCoreOptionDefinition.init).map { ($0.key, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for (key, value) in values {
            guard let definition = definitions[key], definition.rawValue(forStored: value) != nil else {
                throw NetplayError.invalidSettings("This PPSSPP core doesn't support the ad hoc setting \(key).")
            }
        }

        let currentOptions = _bridge.coreOptions
        let restart = PPSSPPAdhocOptions.needsRestart(isHost: isHost, currentOptions: currentOptions)
        let md5 = Self.currentGameMD5.flatMap { $0.isEmpty ? nil : $0 }

        // Remember what to put back, then apply live and persist for this game.
        if let md5 { saveAdhocBackup(forKeys: values.map(\.key) + PPSSPPAdhocOptions.macNibbleKeys, md5: md5) }
        var previous: [String: String] = [:]
        for (key, value) in values {
            previous[key] = currentOptions[key] ?? definitions[key]?.defaultValue
            _bridge.setCoreOption(key, value: value)
            if let md5, let definition = definitions[key] {
                UserDefaults.standard.set(definition.storedRepresentation(forRaw: value), forKey: Self.perGameKeyPrefix(md5: md5) + key)
            }
        }
        // A saved MAC would be shared by every device that copied the setting.
        // Cleared, the core picks a random one at each boot.
        if md5 != nil { Self.clearStoredMACNibbles(md5: md5) }

        let room = makePPSSPPRoom(settings: settings, address: serverIPv4)
        _ppssppAdhocSession = PPSSPPAdhocSession(role: role, room: room, md5: md5, previousLiveValues: previous)
        // The thin wrapper can't see PPSSPP's ad hoc state, so a client counts
        // as connected once its settings are in; the game's own ad hoc menu
        // shows whether it found the host.
        updateNetplayState(isHost ? .hosting(room: room) : .connected(session: NetplaySession(
            room: room,
            role: role,
            peers: [],
            frameDelay: 0,
            isRollbackEnabled: false
        )))

        if restart {
            _bridge.resetEmulationAfterCoreOptionsApplied()
        }
        let paused = (self as PVEmulatorCore).isEmulationPaused
        PVOSDNotification.postMessage(
            Self.ppssppSessionMessage(isHost: isHost, address: serverIPv4, restarting: restart, paused: paused),
            type: .info,
            duration: Self.ppssppSessionMessageDuration
        )
        ILOG("ThinCore PPSSPP ad hoc: \(isHost ? "hosting on" : "joining") \(serverIPv4), restart: \(restart)")
    }

    /// End the session: put every option back and drop the persisted values.
    func stopPPSSPPAdhoc() {
        guard let session = _ppssppAdhocSession else { return }
        _ppssppAdhocSession = nil
        _bridge.cancelResetAfterCoreOptionsApplied()
        for (key, value) in session.previousLiveValues {
            _bridge.setCoreOption(key, value: value)
        }
        if let md5 = session.md5 { Self.restoreAdhocBackup(md5: md5) }
        updateNetplayState(.idle)
        ILOG("ThinCore PPSSPP ad hoc: session stopped")
    }

    /// Put back the options of a session that never stopped (the app was
    /// killed while hosting), so this boot doesn't start on stale ad hoc values.
    /// A live session can't exist at boot: a restart keeps this core instance.
    func restoreStalePPSSPPAdhocOptions() {
        guard let md5 = Self.currentGameMD5, !md5.isEmpty,
              UserDefaults.standard.dictionary(forKey: Self.adhocBackupKey(md5: md5)) != nil else { return }
        WLOG("ThinCore PPSSPP ad hoc: restoring options left by a session that never stopped")
        Self.restoreAdhocBackup(md5: md5)
    }

    // MARK: Persistence backup

    private static let backupPresentKey = "present"
    private static let backupAbsentKey = "absent"

    static func adhocBackupKey(md5: String) -> String {
        "PVThinLibretroCore.ppssppAdhocBackup.\(md5)"
    }

    /// Every UserDefaults key a session writes or clears for `optionKey`.
    private static func adhocStorageKeys(forOptionKey optionKey: String, md5: String) -> [String] {
        [perGameKeyPrefix(md5: md5) + optionKey, "\(String(describing: PVThinLibretroCore.self)).\(optionKey)"]
    }

    /// Record the stored value (or its absence) of each key, so `restoreAdhocBackup` can undo the session.
    private func saveAdhocBackup(forKeys optionKeys: [String], md5: String) {
        let defaults = UserDefaults.standard
        let backupKey = Self.adhocBackupKey(md5: md5)
        // Never overwrite a backup with already-modified values.
        guard defaults.dictionary(forKey: backupKey) == nil else { return }
        var present: [String: Any] = [:]
        var absent: [String] = []
        for optionKey in optionKeys {
            for storageKey in Self.adhocStorageKeys(forOptionKey: optionKey, md5: md5) {
                if let value = defaults.object(forKey: storageKey) {
                    present[storageKey] = value
                } else {
                    absent.append(storageKey)
                }
            }
        }
        defaults.set([Self.backupPresentKey: present, Self.backupAbsentKey: absent], forKey: backupKey)
    }

    /// Undo `saveAdhocBackup`: restore what was stored, remove what was not.
    static func restoreAdhocBackup(md5: String) {
        let defaults = UserDefaults.standard
        let backupKey = adhocBackupKey(md5: md5)
        guard let backup = defaults.dictionary(forKey: backupKey) else { return }
        for (storageKey, value) in backup[backupPresentKey] as? [String: Any] ?? [:] {
            defaults.set(value, forKey: storageKey)
        }
        for storageKey in backup[backupAbsentKey] as? [String] ?? [] {
            defaults.removeObject(forKey: storageKey)
        }
        defaults.removeObject(forKey: backupKey)
    }

    /// Remove any saved MAC nibble for this game, and core-wide.
    private static func clearStoredMACNibbles(md5: String?) {
        guard let md5 else { return }
        for optionKey in PPSSPPAdhocOptions.macNibbleKeys {
            for storageKey in adhocStorageKeys(forOptionKey: optionKey, md5: md5) {
                UserDefaults.standard.removeObject(forKey: storageKey)
            }
        }
    }

    // MARK: Presentation

    private func makePPSSPPRoom(settings: NetplaySettings, address: String) -> NetplayRoom {
        let gameName = _bridge.romPath.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent } ?? ""
        return NetplayRoom(
            hostName: settings.nickname.isEmpty ? "Provenance" : settings.nickname,
            gameName: gameName,
            gameHash: "",
            coreIdentifier: coreIdentifier ?? "",
            maxPlayers: settings.maxPlayers,
            currentPlayers: 1,
            isLAN: true,
            hostAddress: address,
            port: PPSSPPAdhocOptions.serverPort,
            allowsSpectators: false,
            discoverySource: .manual
        )
    }

    /// What to tell the player: the game itself still has to open its ad hoc menu.
    static func ppssppSessionMessage(isHost: Bool, address: String, restarting: Bool, paused: Bool) -> String {
        var restartNote = ""
        if restarting {
            restartNote = paused
                ? " The game restarts when you resume."
                : " The game is restarting to apply the network settings."
        }
        if isHost {
            return "Hosting on \(address).\(restartNote) Open the game's Ad Hoc multiplayer menu and create a game, then have the other player join."
        }
        return "Joining \(address).\(restartNote) Open the game's Ad Hoc multiplayer menu and join the host's game."
    }
}
