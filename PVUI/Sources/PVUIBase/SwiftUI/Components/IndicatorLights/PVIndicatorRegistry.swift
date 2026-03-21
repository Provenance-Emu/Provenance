//
//  PVIndicatorRegistry.swift
//  PVUIBase
//
//  Central registry for managing persistent HUD indicator lights.
//
//  Usage:
//    // Register/update an indicator
//    PVIndicatorRegistry.shared.update(.jitStatus, state: .active)
//
//    // Observe changes
//    PVIndicatorRegistry.shared.$indicators
//      .sink { indicators in /* update UI */ }
//

import Combine
import SwiftUI
#if canImport(PVJIT)
import PVJIT
#endif
#if canImport(PVJIT)
import JITManager
#endif

import PVLogging

// MARK: - Registry

/// A singleton registry that manages the state of all HUD indicator lights.
///
/// The registry provides a centralized way to update indicator states from anywhere
/// in the app, and publishes changes for UI components to observe.
@MainActor
public final class PVIndicatorRegistry: ObservableObject {

    /// Shared singleton instance.
    public static let shared = PVIndicatorRegistry()

    /// Current states of all registered indicators.
    @Published public private(set) var indicators: [PVIndicatorID: PVIndicatorState] = [:]

    /// Whether any indicators are currently visible.
    public var hasVisibleIndicators: Bool {
        indicators.values.contains { $0.isVisible }
    }

    /// Ordered list of visible indicators for display.
    public var visibleIndicators: [PVIndicatorState] {
        PVIndicatorID.allCases.compactMap { id in
            guard let state = indicators[id], state.isVisible else { return nil }
            return state
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private var jitObserverTokens: [NSObjectProtocol] = []

    // MARK: - Initialization

    private init() {
        setupJITObservers()
    }

//    deinit {
//        removeJITObservers()
//    }

    // MARK: - Public API

    /// Updates the state of an indicator.
    /// - Parameters:
    ///   - id: The indicator identifier.
    ///   - state: The new state to apply.
    public func update(_ id: PVIndicatorID, state: PVIndicatorState) {
        let previousState = indicators[id]
        indicators[id] = state

        // Trigger pulse animation on state change
        if previousState != nil && previousState?.color != state.color {
            triggerPulse(for: id)
        }
    }

    /// Updates the JIT indicator with a predefined state.
    /// - Parameter jitState: The JIT state to display.
    public func updateJIT(_ jitState: PVJITIndicatorState) {
        update(.jitStatus, state: jitState.indicatorState)
    }

    /// Updates the analog mode indicator.
    /// - Parameter state: The analog mode state to display.
    public func updateAnalogMode(_ state: PVAnalogModeIndicatorState) {
        update(.analogMode, state: state.indicatorState)
    }

    /// Updates the MFi+ swap/modifier mode indicator.
    /// - Parameter state: The swap mode state to display.
    public func updateSwapMode(_ state: PVSwapModeIndicatorState) {
        let previousState = indicators[.swapMode]
        let wasVisible = previousState?.isVisible ?? false

        update(.swapMode, state: state.indicatorState)

        let newState = indicators[.swapMode]
        let isVisible = newState?.isVisible ?? false
        let colorChanged = previousState?.color != newState?.color

        // Only trigger an extra pulse when we became visible and the generic
        // update(_:state:) did not already pulse (no previous state or no color change).
        if !wasVisible && isVisible && (previousState == nil || !colorChanged) {
            triggerPulse(for: .swapMode)
        }
    }


    /// Removes an indicator from the registry.
    /// - Parameter id: The indicator identifier to remove.
    public func remove(_ id: PVIndicatorID) {
        indicators.removeValue(forKey: id)
    }

    /// Clears all indicators.
    public func clearAll() {
        indicators.removeAll()
    }

    /// Returns the current state for a specific indicator.
    /// - Parameter id: The indicator identifier.
    /// - Returns: The current state, or nil if not registered.
    public func state(for id: PVIndicatorID) -> PVIndicatorState? {
        indicators[id]
    }

    /// Triggers a pulse animation for an indicator.
    /// - Parameter id: The indicator identifier.
    public func triggerPulse(for id: PVIndicatorID) {
        guard var state = indicators[id] else { return }
        state = PVIndicatorState(
            id: state.id,
            color: state.color,
            label: state.label,
            description: state.description,
            isVisible: state.isVisible,
            isPulsing: true
        )
        indicators[id] = state

        // Turn off pulse after animation completes
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard var state = self?.indicators[id], state.isPulsing else { return }
            state = PVIndicatorState(
                id: state.id,
                color: state.color,
                label: state.label,
                description: state.description,
                isVisible: state.isVisible,
                isPulsing: false
            )
            self?.indicators[id] = state
        }
    }

    // MARK: - JIT Observation

    private func setupJITObservers() {
        #if canImport(PVJIT) && os(iOS) && !targetEnvironment(macCatalyst)
        // Observe JIT acquired notification
        let acquiredToken = NotificationCenter.default.addObserver(
            forName: Notification.Name("org.provenance-emu.provenance.jit-acquired"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateJIT(.active)
            ILOG("Indicator: JIT acquired, updated indicator to active")
        }
        jitObserverTokens.append(acquiredToken)

        // Observe JIT failure notification
        let failureToken = NotificationCenter.default.addObserver(
            forName: Notification.Name("org.provenance-emu.provenance.jit-altjit-failure"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            #if canImport(JITManager)
            // Check if JIT was actually acquired despite the failure
            if DOLJitManager.shared.appHasAcquiredJit() {
                self?.updateJIT(.active)
            } else {
                self?.updateJIT(.failed)
            }
            #else
            self?.updateJIT(.failed)
            WLOG("Indicator: JIT AltJIT failed, JITManager not supported, assuming failure")
            #endif
            WLOG("Indicator: JIT AltJIT failed, updated indicator accordingly")
        }
        jitObserverTokens.append(failureToken)

        // Initialize JIT state
        refreshJITState()
        #endif
    }

    private func removeJITObservers() {
        jitObserverTokens.forEach { token in
            NotificationCenter.default.removeObserver(token)
        }
        jitObserverTokens.removeAll()
    }

    /// Refreshes the JIT state based on current DOLJitManager status.
    /// Call this when the emulator starts to ensure correct initial state.
    public func refreshJITState() {
        #if canImport(PVJIT) && os(iOS) && !targetEnvironment(macCatalyst)
        let jitManager = DOLJitManager.shared
        if jitManager.appHasAcquiredJit() {
            updateJIT(.active)
        } else {
            // Default to interpreter mode on iOS until JIT is acquired
            // On simulator, mark as not applicable
            #if targetEnvironment(simulator)
            updateJIT(.notApplicable)
            #else
            updateJIT(.interpreter)
            #endif
        }
        #elseif targetEnvironment(simulator)
        updateJIT(.notApplicable)
        #else
        // tvOS or other platforms where JIT isn't supported
        updateJIT(.notApplicable)
        #endif
    }
}

