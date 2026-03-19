//
//  PVRetroArchCoreCore+PVNetplayCapable.swift
//  PVRetroArch
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Forwards PVNetplayCapable calls from PVRetroArchCoreCore to its
//  underlying PVRetroArchCoreBridge, which already conforms to the protocol.
//
//  PVEmulatorViewController casts `core` (typed as PVEmulatorCore) to
//  `any PVNetplayCapable` to register the bridge with PVNetplayManager.
//

import Foundation
import Combine
import PVNetplay

// MARK: - PVNetplayCapable forwarding

extension PVRetroArchCoreCore: PVNetplayCapable {

    public var supportsNetplay: Bool {
        _bridge.supportsNetplay
    }

    public var netplayEngineName: String {
        _bridge.netplayEngineName
    }

    public func startNetplay(role: NetplayRole, settings: NetplaySettings) async throws {
        try await _bridge.startNetplay(role: role, settings: settings)
    }

    public func stopNetplay() async {
        await _bridge.stopNetplay()
    }

    public var netplayState: NetplayState {
        _bridge.netplayState
    }

    public var netplayStatePublisher: AnyPublisher<NetplayState, Never> {
        _bridge.netplayStatePublisher
    }
}
