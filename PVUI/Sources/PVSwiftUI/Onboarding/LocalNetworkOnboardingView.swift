//
//  LocalNetworkOnboardingView.swift
//  PVSwiftUI
//
//  One-time iOS retrowave alert that explains why iOS is asking for the
//  Local Network permission. The system alert from `UILocalNetworkPrivacy`
//  fires independently when Hummingbird / Bonjour first touches the network;
//  this overlay just adds context so the user doesn't deny it on reflex.
//
//  Skipped entirely on tvOS / macOS (no local-network permission prompt).
//

import SwiftUI
import PVLogging
import PVSettings

#if canImport(PVUIBase)
import PVUIBase
#endif

// MARK: - Defaults wrapper

@MainActor
public enum LocalNetworkOnboarding {

    /// Whether the alert should be presented for the active platform/session.
    public static var shouldPresent: Bool {
        #if os(iOS) || targetEnvironment(macCatalyst)
        return !Defaults[.localNetworkOnboardingShown]
        #else
        return false
        #endif
    }

    /// Persist the "user has been informed" flag.
    public static func markShown() {
        Defaults[.localNetworkOnboardingShown] = true
    }
}

// MARK: - View modifier

public extension View {
    /// Attach to the root view. Presents the retrowave onboarding alert once
    /// per install (iOS / Catalyst only) when `bootCompleted` flips true.
    func localNetworkOnboarding(bootCompleted: Bool) -> some View {
        modifier(LocalNetworkOnboardingModifier(bootCompleted: bootCompleted))
    }
}

private struct LocalNetworkOnboardingModifier: ViewModifier {
    let bootCompleted: Bool
    @State private var isPresented = false

    func body(content: Content) -> some View {
        #if os(iOS) || targetEnvironment(macCatalyst)
        content
            // `.task(id:)` fires on initial appearance AND whenever the
            // dependency value changes. Using `.onChange` here would miss
            // the case where the view appears after bootup is already
            // complete (subsequent quick relaunches).
            .task(id: bootCompleted) {
                guard bootCompleted, LocalNetworkOnboarding.shouldPresent else { return }
                // Defer slightly so the alert animates in *after* the
                // boot transition settles and after iOS has had a chance to
                // surface its own Local Network permission alert.
                try? await Task.sleep(nanoseconds: 500_000_000)
                isPresented = true
            }
            .retroAlert(
                "Local Network Access",
                message: "Provenance just asked iOS for permission to find devices on your local network. This is what powers the in-app Web Uploader and WebDAV server — they let you drag-and-drop ROMs, BIOS files, and save states from another device on the same Wi-Fi.\n\nIf you tapped “Don't Allow”, you can still play games — the file server simply won't be reachable until you re-enable it in Settings → Provenance → Local Network.",
                isPresented: $isPresented,
                alertType: .standard
            ) {
                RetroAlertButton(title: "Got It", style: .primary) {
                    LocalNetworkOnboarding.markShown()
                    isPresented = false
                }
            }
        #else
        content
        #endif
    }
}
