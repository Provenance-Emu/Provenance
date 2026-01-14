import Foundation
import Combine
import SwiftUI

/// Thread-safe actor for managing emulation state
/// All access is automatically serialized to prevent race conditions
public actor EmulationState {
    /// Singleton instance
    public static let shared = EmulationState()

    private init() {}

    /// State model for emulation (Sendable for safe cross-actor transfer)
    public struct State: Sendable, Equatable {
        public var coreClassName: String = ""
        public var systemName: String = ""
        public var isOn: Bool = false
    }

    /// Current emulation state
    public private(set) var state = State()

    /// Publisher for observing state changes from MainActor contexts
    /// CurrentValueSubject is internally thread-safe; unsafe annotation bypasses Sendable check
    public nonisolated(unsafe) let stateSubject = CurrentValueSubject<State, Never>(State())

    /// Current core class name
    public var coreClassName: String {
        get { state.coreClassName }
        set {
            state.coreClassName = newValue
            publishState()
        }
    }

    /// Current system name
    public var systemName: String {
        get { state.systemName }
        set {
            state.systemName = newValue
            publishState()
        }
    }

    /// Whether emulation is currently active
    public var isOn: Bool {
        get { state.isOn }
        set {
            state.isOn = newValue
            publishState()
        }
    }

    /// Update state atomically with a closure
    public func update(_ transform: @Sendable (inout State) -> Void) {
        transform(&state)
        publishState()
    }

    /// Publish current state to the subject for Combine subscribers
    private func publishState() {
        stateSubject.send(state)
    }

    /// Set core class name
    public func setCoreClassName(_ value: String) {
        coreClassName = value
    }

    /// Set system name
    public func setSystemName(_ value: String) {
        systemName = value
    }

    /// Set isOn state
    public func setIsOn(_ value: Bool) {
        isOn = value
    }

    /// Reset all state to defaults
    public func reset() {
        state = State()
        publishState()
    }
}

/// MainActor wrapper for synchronous access where needed
/// Use this sparingly - prefer async access when possible
@MainActor
public final class EmulationStateSync {
    public static let shared = EmulationStateSync()

    private var cachedState = EmulationState.State()
    private var cancellable: AnyCancellable?

    private init() {
        cancellable = EmulationState.shared.stateSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.cachedState = state
            }
    }

    /// Cached isOn state (may be slightly stale, but thread-safe)
    public var isOn: Bool { cachedState.isOn }

    /// Cached coreClassName (may be slightly stale, but thread-safe)
    public var coreClassName: String { cachedState.coreClassName }

    /// Cached systemName (may be slightly stale, but thread-safe)
    public var systemName: String { cachedState.systemName }
}
