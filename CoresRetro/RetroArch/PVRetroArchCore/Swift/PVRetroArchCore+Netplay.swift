//
//  PVRetroArchCore+Netplay.swift
//  PVRetroArch
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Swift convenience wrappers over PVRetroArchCoreBridge+Netplay.h/.mm.
//  ObjC methods with NSError** are exposed as Swift throwing functions.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// Netplay convenience methods on PVRetroArchCoreBridge.
public extension PVRetroArchCoreBridge {

    // MARK: - Publisher

    /// Publisher that emits netplay status changes (polled once/sec while active).
    var retroArchNetplayStatusPublisher: AnyPublisher<PVRetroArchNetplayStatus, Never> {
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .compactMap { [weak self] _ in self?.netplayStatus }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    // MARK: - Host

    /// Start hosting a RetroArch netplay room.
    /// - Parameters:
    ///   - nickname: Display name shown to peers (defaults to device name).
    ///   - port: UDP port to listen on (default 55435).
    ///   - frameDelay: Input delay frames (0 = rollback only).
    /// - Throws: `NSError` with `PVRetroArchNetplayErrorDomain` on failure.
    func startNetplayHosting(
        nickname: String? = nil,
        port: UInt16 = 55435,
        frameDelay: Int = 0
    ) throws {
        #if os(tvOS)
        let name = nickname ?? "Provenance TV"
        #elseif canImport(UIKit)
        let name = nickname ?? UIDevice.current.name
        #else
        let name = nickname ?? "Provenance"
        #endif
        // ObjC method with NSError** parameter is bridged as a throwing Swift function
        try netplayStartHosting(
            withNickname: name,
            port: port,
            frameDelay: Int32(frameDelay)
        )
    }

    /// Connect to a remote RetroArch netplay host.
    /// - Parameters:
    ///   - host: IP address or hostname.
    ///   - port: UDP port the host is listening on.
    ///   - nickname: Display name shown to peers.
    ///   - frameDelay: Input delay frames.
    ///   - spectate: If `true`, join as spectator only.
    /// - Throws: `NSError` with `PVRetroArchNetplayErrorDomain` on failure.
    func connectToNetplay(
        host: String,
        port: UInt16 = 55435,
        nickname: String? = nil,
        frameDelay: Int = 0,
        spectate: Bool = false
    ) throws {
        #if os(tvOS)
        let name = nickname ?? "Provenance TV"
        #elseif canImport(UIKit)
        let name = nickname ?? UIDevice.current.name
        #else
        let name = nickname ?? "Provenance"
        #endif
        try netplayConnect(
            toHost: host,
            port: port,
            nickname: name,
            frameDelay: Int32(frameDelay),
            spectate: spectate
        )
    }

    /// Stop the current netplay session.
    func stopNetplaySession() {
        netplayStop()
    }

    /// Whether a netplay session is currently active.
    var isNetplayActive: Bool {
        netplayStatus != .idle
    }
}
