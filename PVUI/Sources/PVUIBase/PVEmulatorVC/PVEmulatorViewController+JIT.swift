//
//  PVEmulatorViewController+JIT.swift
//  PVUIBase
//
//  JIT status indicator integration for PVEmulatorViewController.
//  Part of issue #2796.
//

import PVSettings
import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(PVJIT)
import PVJIT
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
        // Skip for cores that don't support JIT
        // For now, we show the indicator for all cores that have JIT capability
        // When the JIT Capability Matrix (#2793) is implemented, this can be refined

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

        // Determine if the current core benefits from JIT
        // For now, we show for all cores but in the future this can use the JIT Capability Matrix
        let requiresJIT = coreRequiresJIT()
        indicator.updateForCore(requiresJIT: requiresJIT)
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
    /// This is a placeholder implementation until the JIT Capability Matrix (#2793) is implemented.
    /// Currently returns `true` for all cores since JIT generally improves performance.
    private func coreRequiresJIT() -> Bool {
        // TODO: When JIT Capability Matrix is available, check core.identifier against the matrix
        // For now, show the indicator for all cores that can benefit from JIT
        return true
    }
    #endif
}
