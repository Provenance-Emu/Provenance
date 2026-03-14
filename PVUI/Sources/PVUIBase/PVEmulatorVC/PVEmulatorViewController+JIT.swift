//
//  PVEmulatorViewController+JIT.swift
//  PVUIBase
//
//  JIT status indicator integration for PVEmulatorViewController.
//  Part of issue #2796.
//

import PVEmulatorCore
import PVSettings
import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(PVJIT)
import PVJIT
#endif
#if canImport(JITManager)
import JITManager
#endif

// MARK: - Stored properties via associated objects

private enum JITAssociatedKeys {
    static var jitIndicatorVC = "jitIndicatorViewController"
    static var showJITIndicatorCancellable = "showJITIndicatorCancellable"
}

public extension PVEmulatorViewController {

    // MARK: - Associated object accessors

    #if canImport(PVJIT)
    /// The JIT status indicator view controller, or `nil` if not set up.
    internal var jitIndicatorViewController: JITStatusIndicatorViewController? {
        get { objc_getAssociatedObject(self, &JITAssociatedKeys.jitIndicatorVC) as? JITStatusIndicatorViewController }
        set { objc_setAssociatedObject(self, &JITAssociatedKeys.jitIndicatorVC, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    #endif

    /// Cancellable for observing the showJITStatusIndicator preference
    private var showJITIndicatorCancellable: AnyCancellable? {
        get { objc_getAssociatedObject(self, &JITAssociatedKeys.showJITIndicatorCancellable) as? AnyCancellable }
        set { objc_setAssociatedObject(self, &JITAssociatedKeys.showJITIndicatorCancellable, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Lifecycle

    /// Call this in viewDidLoad to set up the JIT indicator if needed.
    func setupJITIndicatorIfNeeded() {
        #if canImport(PVJIT)
        // Observe the preference
        configureJITIndicatorPreferenceObservation()

        // Apply initial state
        Task { @MainActor in
            self.applyJITIndicatorVisibilityPreference(Defaults[.showJITStatusIndicator])
        }
        #endif
    }

    /// Call this when the view controller is being destroyed.
    func cleanupJITIndicator() {
        #if canImport(PVJIT)
        showJITIndicatorCancellable?.cancel()
        showJITIndicatorCancellable = nil
        removeJITIndicator()
        #endif
    }

    // MARK: - Visibility

    #if canImport(PVJIT)
    @MainActor
    private func applyJITIndicatorVisibilityPreference(_ enabled: Bool) {
        // The JIT Capability Matrix (PVJITRequirement, #2793) is used inside coreRequiresJIT()
        // to decide whether the indicator is relevant for the current core.

        if enabled {
            setupJITIndicator()
        } else {
            removeJITIndicator()
        }
    }

    private func configureJITIndicatorPreferenceObservation() {
        guard showJITIndicatorCancellable == nil else { return }
        showJITIndicatorCancellable = Defaults.publisher(.showJITStatusIndicator)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                guard let self else { return }
                Task { @MainActor in
                    self.applyJITIndicatorVisibilityPreference(change.newValue)
                }
            }
    }

    // MARK: - Setup / Teardown

    @MainActor
    private func setupJITIndicator() {
        guard jitIndicatorViewController == nil else { return }

        // Only add the indicator for cores that actually benefit from JIT.
        // Avoids adding a full-screen child VC (even a transparent one) for every core.
        guard coreRequiresJIT() else {
            ILOG("[JIT] Core does not require JIT — skipping indicator")
            return
        }

        let indicator = JITStatusIndicatorViewController()
        jitIndicatorViewController = indicator

        addChild(indicator)
        view.addSubview(indicator.view)
        indicator.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            indicator.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            indicator.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            indicator.view.topAnchor.constraint(equalTo: view.topAnchor),
            indicator.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        indicator.didMove(toParent: self)

        // Inform the indicator whether this core strictly requires JIT.
        // Use PVEmulatorCore.jitRequirement (set as a Swift property override on each
        // PVEmulatorCore subclass, populated by the JIT Capability Matrix from #2793).
        // Only `.requiredOrCrash` cores gate the `.unavailable` status / persistent toast.
        indicator.updateForCore(requiresJIT: core.jitRequirement == .requiredOrCrash)
    }

    @MainActor
    private func removeJITIndicator() {
        guard let indicator = jitIndicatorViewController else { return }
        indicator.willMove(toParent: nil)
        indicator.view.removeFromSuperview()
        indicator.removeFromParent()
        jitIndicatorViewController = nil
    }

    // MARK: - Core JIT Capability

    /// Determines if the current core requires or benefits from JIT.
    /// Returns `false` for cores that do not use JIT to avoid showing the indicator on every core.
    /// Uses `PVEmulatorCore.jitRequirement` (the `PVPrimitives.PVJITRequirement` 4-case enum)
    /// for an authoritative, per-core answer without string lookups (#2793).
    private func coreRequiresJIT() -> Bool {
        // Quick-exit: if the JIT manager has no JIT type configured, JIT is not in play at all
        guard DOLJitManager.shared.getJitType() != .none else { return false }

        // Use the core's own jitRequirement property — set as a Swift override on each
        // PVEmulatorCore subclass. hasJIT is true for .optional, .requiredOrCrash, and
        // .automaticWithFallback; false only for .notSupported.
        return core.jitRequirement.hasJIT
    }
    #endif
}
