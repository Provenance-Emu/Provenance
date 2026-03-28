//
//  PVOpenIntentResponse.swift
//  Provenance
//
//  Created by Joseph Mattiello
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Intents

#if os(iOS)
/// Legacy response code for `PVOpenIntent`.
///
/// - Important: Deprecated. Use `LaunchGameIntent` from `PVAppIntents` instead.
@available(*, deprecated, message: "Use LaunchGameIntent from PVAppIntents instead.")
@objc(PVOpenIntentResponseCode)
enum PVOpenIntentResponseCode: Int {
    case unspecified = 0
    case success = 1
    case failure = 2
}

@available(*, deprecated, message: "Use LaunchGameIntent from PVAppIntents instead.")
@objc(PVOpenIntentResponse)
class PVOpenIntentResponse: INIntentResponse {
    private var _codeValue: Int = 0

    /// Response code as enum - provides type-safe access to the response code
    var code: PVOpenIntentResponseCode {
        get {
            return PVOpenIntentResponseCode(rawValue: _codeValue) ?? .unspecified
        }
        set {
            _codeValue = newValue.rawValue
        }
    }

    override init() {
        super.init()
        _codeValue = PVOpenIntentResponseCode.unspecified.rawValue
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        if coder.containsValue(forKey: "code") {
            _codeValue = coder.decodeInteger(forKey: "code")
        }
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(_codeValue, forKey: "code")
    }

    convenience init(code: PVOpenIntentResponseCode, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }
}
#endif
