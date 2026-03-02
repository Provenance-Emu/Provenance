//
//  AppCenterBootstrapTask.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2026-03-02.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

#if canImport(AppCenter)
import AppCenter
import AppCenterAnalytics
#endif

/// Initialises AppCenter Analytics (App Store builds only).
///
/// Requires `BootstrapKey.logging`. Provides `BootstrapKey.analytics`.
struct AppCenterBootstrapTask: BootstrapTask {
    var name: String { "AppCenter" }
    var dependencies: [String] { [BootstrapKey.logging] }
    var provisions: [String] { [BootstrapKey.analytics] }

    /// Whether this task should actually configure AppCenter.
    /// Defaults to checking the app's `isAppStore` flag.
    private let isAppStore: Bool

    init(isAppStore: Bool) {
        self.isAppStore = isAppStore
    }

    func execute() async throws {
#if canImport(AppCenter)
        guard isAppStore else {
            ILOG("AppCenterBootstrapTask: Skipping — not an App Store build")
            return
        }
        guard let secretKey = Bundle.main.object(forInfoDictionaryKey: "appcenter") as? String else {
            ELOG("AppCenterBootstrapTask: No value for Info.plist key 'appcenter'")
            return
        }
        AppCenter.configure(withAppSecret: secretKey)
        if AppCenter.isConfigured {
            AppCenter.startService(Analytics.self)
            AppCenter.startService(Crashes.self)
            ILOG("AppCenterBootstrapTask: AppCenter initialised")
        } else {
            ELOG("AppCenterBootstrapTask: AppCenter not configured")
        }
#else
        ILOG("AppCenterBootstrapTask: AppCenter not available on this target")
#endif
    }
}
