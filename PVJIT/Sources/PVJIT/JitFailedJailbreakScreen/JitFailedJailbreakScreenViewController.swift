// Copyright 2021 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

import Foundation
import SwiftUI
// UIKit is unavailable on macOS; PVJIT declares .macOS(.v14) so the manifest can
// participate in the package graph, but these UIKit screens are iOS/tvOS-only.
#if canImport(UIKit)
import UIKit
import JITManager

/// Shared SwiftUI content for the fatal JIT failure screen.
private struct JitFailedJailbreakScreenRootView: View {
    let auxiliaryError: String?
    let onClose: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.04, blue: 0.08), Color(red: 0.04, green: 0.01, blue: 0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.yellow)

                Text("Performance Mode Unavailable")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(auxiliaryError ?? "No additional error details were available.")
                    .font(.system(size: 20, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 760)

                Button("OK") {
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 48)
        }
    }
}

/// Hosting controller bridge for the fatal JIT failure screen.
final class JitFailedJailbreakScreenViewController: UIHostingController<AnyView> {
    weak var delegate: JitScreenDelegate?

    init() {
        let auxiliaryError = DOLJitManager.shared.getAuxiliaryError()
        super.init(
            rootView: AnyView(JitFailedJailbreakScreenRootView(auxiliaryError: auxiliaryError) { })
        )
        rootView = AnyView(JitFailedJailbreakScreenRootView(auxiliaryError: auxiliaryError) { [weak self] in
            guard let self else { return }
            // Always return false so that emulation never starts
            self.delegate?.didFinishJitScreen(result: false, sender: self)
        })
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
