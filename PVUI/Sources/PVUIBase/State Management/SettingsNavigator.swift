//
//  SettingsNavigator.swift
//  PVUIBase
//

import Foundation
import Combine

public enum SettingsDestination: Equatable {
    case none
    case cloudSync
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
