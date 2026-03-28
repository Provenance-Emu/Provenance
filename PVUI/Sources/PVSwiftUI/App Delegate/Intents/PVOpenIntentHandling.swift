//
//  PVOpenIntentHandling.swift
//  Provenance
//
//  Created by Joseph Mattiello
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Intents

#if os(iOS)
/// Legacy handling protocol for `PVOpenIntent`.
///
/// - Important: Deprecated. Handling is now performed by `LaunchGameIntent` from `PVAppIntents`.
@available(iOS 14.0, *)
@available(*, deprecated, message: "Use LaunchGameIntent from PVAppIntents instead.")
@objc(PVOpenIntentHandling)
protocol PVOpenIntentHandling: NSObjectProtocol {
    func handle(intent: PVOpenIntent, completion: @escaping (PVOpenIntentResponse) -> Void)

    @objc optional
    func confirm(intent: PVOpenIntent, completion: @escaping (PVOpenIntentResponse) -> Void)

    @objc optional
    func resolveMd5(for intent: PVOpenIntent, with completion: @escaping (INStringResolutionResult) -> Void)

    @objc optional
    func resolveGameName(for intent: PVOpenIntent, with completion: @escaping (INStringResolutionResult) -> Void)

    @objc optional
    func resolveSystemName(for intent: PVOpenIntent, with completion: @escaping (INStringResolutionResult) -> Void)
}
#endif

