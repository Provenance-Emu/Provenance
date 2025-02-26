import Foundation
import Combine
import SwiftUI

/*
  Usage:

 ```swift
 // Access state
 let className = await EmulationState.shared.coreClassName

 // Update state
 await EmulationState.shared.setCoreClassName("NewCore")
 ```
 */

/// Main actor for managing emulation state
//@MainActor
@objc
public final class EmulationState: NSObject, ObservableObject {
    @objc
    nonisolated(unsafe) public static let shared = EmulationState()

    private override init() {}

    /// State model for emulation
    @Published public private(set) var state = State()

    public struct State {
        public var coreClassName: String = ""
        public var systemName: String = ""
        public var isOn: Bool = false
    }

    // Computed properties for direct access
    @objc
    public var coreClassName: String {
        get { state.coreClassName }
        set { state.coreClassName = newValue }
    }

    @objc
    public var systemName: String {
        get { state.systemName }
        set { state.systemName = newValue }
    }

    @objc
    public var isOn: Bool {
        get { state.isOn }
        set { state.isOn = newValue }
    }

    /// Update state
    public func update(_ update: (inout State) -> Void) {
        var newState = state
        update(&newState)
        state = newState
    }
}

/// Convenience methods for state access
@objc
extension EmulationState {
    @objc
    public func setCoreClassName(_ value: String) async {
//        await MainActor.run {
            coreClassName = value
//        }
    }

    @objc
    public func setSystemName(_ value: String) async {
//        await MainActor.run {
            systemName = value
//        }
    }

    @objc
    public func setIsOn(_ value: Bool) async {
//        await MainActor.run {
            isOn = value
//        }
    }
}
