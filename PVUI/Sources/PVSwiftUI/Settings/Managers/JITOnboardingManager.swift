//
//  JITOnboardingManager.swift
//  PVUI
//
//  Created by Provenance on 3/10/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Manages the Apple-safe JIT onboarding flow, showing the education screen
//  when appropriate before attempting JIT acquisition.
//

import SwiftUI
import UIKit
import PVSettings
import PVJIT
import JITManager
import PVLogging

/// Manages the JIT onboarding flow, determining when to show the education screen
@available(iOS 14.0, *)
public final class JITOnboardingManager: ObservableObject {
    public static let shared = JITOnboardingManager()

    @Published public var isShowingOnboarding = false

    private init() {}

    /// Checks if onboarding should be shown for the given core category
    /// - Parameter coreCategory: The identifier for the core category (e.g., "dolphin", "ppsspp")
    /// - Returns: True if onboarding should be shown
    public func shouldShowOnboarding(for coreCategory: String) -> Bool {
        // Don't show if user has dismissed it for this category
        let dismissedCategories = Defaults[.jitOnboardingDismissedCategories]
        guard !dismissedCategories.contains(coreCategory) else {
            return false
        }

        // Only show on iOS (tvOS doesn't support JIT the same way)
        #if os(iOS)
        // Check if we're on a JIT-restricted environment
        let jitManager = DOLJitManager.shared
        let jitType = jitManager.getJitType()

        // If JIT is already acquired or not restricted, no need to show
        if jitManager.appHasAcquiredJit() {
            return false
        }

        // Only show for debugger-type JIT that requires user action
        // If it's already unrestricted or uses other methods, skip onboarding
        if jitType == .notRestricted || jitType == .allowUnsigned {
            return false
        }

        return true
        #else
        return false
        #endif
    }

    /// Presents the JIT onboarding view for the specified core category
    /// - Parameters:
    ///   - coreCategory: The identifier for the core category
    ///   - coreName: The display name of the core (shown in UI)
    ///   - from: The view controller to present from
    ///   - onComplete: Called when the user makes a selection, with a Bool indicating if they chose to enable JIT
    public func presentOnboarding(
        for coreCategory: String,
        coreName: String,
        from viewController: UIViewController,
        onComplete: @escaping (Bool) -> Void
    ) {
        guard shouldShowOnboarding(for: coreCategory) else {
            // Skip onboarding, proceed directly
            onComplete(true)
            return
        }

        isShowingOnboarding = true

        let onboardingView = JITOnboardingView(
            coreCategory: coreCategory,
            coreName: coreName,
            onEnablePerformanceMode: {
                onComplete(true)
            },
            onContinueWithoutJIT: {
                onComplete(false)
            }
        )

        let hostingController = UIHostingController(rootView: onboardingView)
        hostingController.modalPresentationStyle = .formSheet
        hostingController.isModalInPresentation = true

        // Configure for iPhone to use full screen
        if UIDevice.current.userInterfaceIdiom == .phone {
            hostingController.modalPresentationStyle = .fullScreen
        }

        viewController.present(hostingController, animated: true)
    }

    /// Presents the JIT onboarding as a SwiftUI sheet
    /// - Parameters:
    ///   - coreCategory: The identifier for the core category
    ///   - coreName: The display name of the core
    ///   - isPresented: Binding to control sheet presentation
    ///   - onComplete: Called when the user makes a selection
    public func onboardingSheet(
        for coreCategory: String,
        coreName: String,
        isPresented: Binding<Bool>,
        onComplete: @escaping (Bool) -> Void
    ) -> some View {
        JITOnboardingView(
            coreCategory: coreCategory,
            coreName: coreName,
            onEnablePerformanceMode: {
                isPresented.wrappedValue = false
                onComplete(true)
            },
            onContinueWithoutJIT: {
                isPresented.wrappedValue = false
                onComplete(false)
            }
        )
    }

    /// Marks onboarding as dismissed for a specific core category
    /// - Parameter coreCategory: The core category to mark as dismissed
    public func dismissOnboarding(for coreCategory: String) {
        var dismissedCategories = Defaults[.jitOnboardingDismissedCategories]
        dismissedCategories.insert(coreCategory)
        Defaults[.jitOnboardingDismissedCategories] = dismissedCategories
    }

    /// Resets all onboarding dismissals (for testing or if user wants to see tips again)
    public func resetAllDismissals() {
        Defaults[.jitOnboardingDismissedCategories] = Set<String>()
    }
}

// MARK: - Core Category Helpers

@available(iOS 14.0, *)
public extension JITOnboardingManager {
    /// Known core categories that benefit from JIT
    enum CoreCategory {
        case dolphin      // GameCube/Wii
        case ppsspp       // PSP
        case azahar       // 3DS
        case melonDS      // DS
        case flycast      // Dreamcast
        case retroArch    // RetroArch cores
        case other(String)

        public var identifier: String {
            switch self {
            case .dolphin: return "dolphin"
            case .ppsspp: return "ppsspp"
            case .azahar: return "azahar"
            case .melonDS: return "melonds"
            case .flycast: return "flycast"
            case .retroArch: return "retroarch"
            case .other(let id): return id
            }
        }

        public var displayName: String {
            switch self {
            case .dolphin: return "Dolphin"
            case .ppsspp: return "PPSSPP"
            case .azahar: return "Azahar"
            case .melonDS: return "melonDS"
            case .flycast: return "Flycast"
            case .retroArch: return "RetroArch"
            case .other(let id): return id
            }
        }

        /// Whether this core category generally requires JIT for good performance
        public var isJITRecommended: Bool {
            switch self {
            case .dolphin, .ppsspp, .azahar, .flycast:
                return true
            case .melonDS, .retroArch, .other:
                return false
            }
        }
    }

    /// Convenience method to show onboarding for a known core category
    func shouldShowOnboarding(for category: CoreCategory) -> Bool {
        return shouldShowOnboarding(for: category.identifier)
    }

    /// Convenience method to dismiss onboarding for a known core category
    func dismissOnboarding(for category: CoreCategory) {
        dismissOnboarding(for: category.identifier)
    }
}

// MARK: - SwiftUI View Modifier

@available(iOS 14.0, *)
public extension View {
    /// Adds JIT onboarding presentation capability to a view
    func jitOnboarding(
        for coreCategory: String,
        coreName: String,
        isPresented: Binding<Bool>,
        onComplete: @escaping (Bool) -> Void
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            JITOnboardingView(
                coreCategory: coreCategory,
                coreName: coreName,
                onEnablePerformanceMode: {
                    onComplete(true)
                },
                onContinueWithoutJIT: {
                    onComplete(false)
                }
            )
        }
    }
}
