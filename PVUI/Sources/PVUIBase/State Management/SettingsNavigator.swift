//
//  SettingsNavigator.swift
//  PVUIBase
//

import Foundation
import Combine

public enum SettingsDestination: Equatable {
    case none
    case cloudSync
    /// Select a top-level settings tab (iOS tabbed settings UI). Ignored on tvOS.
    case tab(SettingsTab)
}

/// Top-level tabs of the iOS settings UI, in display order.
public enum SettingsTab: Int, Equatable, CaseIterable {
    case general = 0
    case emulation = 1
    case controller = 2
    case advanced = 3
    case about = 4
}

/// Shared settings navigation router to allow programmatic deep links into settings.
public final class SettingsNavigator: ObservableObject {
    public static let shared = SettingsNavigator()

    @Published public var destination: SettingsDestination = .none

    private init() {}

    public func navigate(to destination: SettingsDestination) {
        self.destination = destination
    }
}
