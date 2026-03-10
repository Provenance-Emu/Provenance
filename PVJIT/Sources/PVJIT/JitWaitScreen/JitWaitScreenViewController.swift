// Copyright 2021 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

import Foundation
import SwiftUI
import UIKit
import JITManager

/// SwiftUI-backed wait screen shared by iOS and tvOS while JIT is being acquired.
@MainActor
private final class JitWaitScreenViewModel: ObservableObject {
    @Published var activeAlert: JitWaitAlert?

    /// Called when the wait flow completes successfully or is cancelled.
    var onFinish: ((Bool) -> Void)?

    /// Token used while waiting for a remote debugger to attach.
    let cancellationToken = DOLCancellationToken()

    private var observers: [NSObjectProtocol] = []
    private var hasStarted = false

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    /// Starts JIT acquisition and subscribes to the result notifications once.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        let notificationCenter = NotificationCenter.default
        observers.append(
            notificationCenter.addObserver(
                forName: .DOLJitAcquired,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.onFinish?(true)
            }
        )
        observers.append(
            notificationCenter.addObserver(
                forName: .DOLJitAltJitFailure,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let message: String
                if let error = notification.userInfo?["nserror"] as? NSError {
                    message = error.localizedDescription
                } else {
                    message = "No error message available."
                }
                self?.activeAlert = .altJitFailure(message)
            }
        )

        DOLJitManager.shared.attemptToAcquireJitByWaitingForDebugger(using: cancellationToken)

        if let deviceID = Bundle.main.object(forInfoDictionaryKey: "ALTDeviceID") as? String, deviceID != "dummy" {
            // ALTDeviceID has been set, so we should attempt to acquire by AltJIT instead
            // of just sitting around and waiting for a debugger.
            DOLJitManager.shared.attemptToAcquireJitByAltJIT()
        }

        // We can always try this. If the device is not connected to the VPN, then this
        // request will just silently fail. Other helper apps, such as SideStore or
        // StikDebug, can also attach independently while this screen is visible.
        DOLJitManager.shared.attemptToAcquireJitByJitStreamer()

        if let auxError = DOLJitManager.shared.getAuxiliaryError() {
            activeAlert = .workaroundFailure(auxError)
        }
    }

    /// Retries AltJIT after a recoverable connection failure.
    func retryAltJIT() {
        DOLJitManager.shared.attemptToAcquireJitByAltJIT()
    }

    /// Cancels the wait flow and reports failure back to the presenter.
    func cancel() {
        cancellationToken.cancel()
        onFinish?(false)
    }
}

/// Alerts shown while the wait screen is active.
private enum JitWaitAlert: Identifiable {
    case workaroundFailure(String)
    case altJitFailure(String)

    var id: String {
        switch self {
        case .workaroundFailure:
            return "workaroundFailure"
        case .altJitFailure:
            return "altJitFailure"
        }
    }
}

/// Shared SwiftUI content for the JIT wait screen.
private struct JitWaitScreenRootView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: JitWaitScreenViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.09, blue: 0.15), Color(red: 0.02, green: 0.03, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "bolt.badge.clock.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.yellow)

                Text("Activating Performance Mode")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Provenance is waiting for debugger-based JIT. If you have SideStore, StikDebug, AltStore, or another debugger helper available, keep it nearby while activation completes.")
                    .font(.system(size: 20, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 760)

                ProgressView()
                    .controlSize(.large)
                    .padding(.top, 8)

                HStack(spacing: 16) {
                    Button("Help") {
                        if let url = URL(string: "https://wiki.provenance-emu.com/jit-help") {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Cancel", role: .cancel) {
                        viewModel.cancel()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 48)
        }
        .task {
            viewModel.start()
        }
        .alert(item: $viewModel.activeAlert) { alert in
            switch alert {
            case .workaroundFailure(let message):
                let fallbackMessage =
                    "Provenance attempted to prepare Performance Mode automatically, " +
                    "but the following error was returned:\n\n\(message)\n\n" +
                    "Provenance will now fallback to waiting for a remote debugger."
                return Alert(
                    title: Text("Automatic Setup Failed"),
                    message: Text(fallbackMessage),
                    dismissButton: .default(Text("OK"))
                )
            case .altJitFailure(let message):
                return Alert(
                    title: Text("Failed to Contact AltJIT"),
                    message: Text("\(message)\n\nYou can retry AltJIT or continue waiting for another debugger-based helper such as SideStore or StikDebug."),
                    primaryButton: .default(Text("Retry AltJIT")) {
                        viewModel.retryAltJIT()
                    },
                    secondaryButton: .cancel(Text("Wait for Another Helper")) {
                    }
                )
            }
        }
    }
}

/// Hosting controller bridge so the existing UIKit presentation flow can
/// present the shared SwiftUI wait screen on both iOS and tvOS.
public final class JitWaitScreenViewController: UIHostingController<AnyView> {
    public weak var delegate: JitScreenDelegate? {
        didSet {
            viewModel.onFinish = { [weak self] result in
                guard let self else { return }
                self.delegate?.didFinishJitScreen(result: result, sender: self)
            }
        }
    }

    private let viewModel: JitWaitScreenViewModel

    public init() {
        let viewModel = JitWaitScreenViewModel()
        self.viewModel = viewModel
        super.init(rootView: AnyView(JitWaitScreenRootView(viewModel: viewModel)))
        self.viewModel.onFinish = { [weak self] result in
            guard let self else { return }
            self.delegate?.didFinishJitScreen(result: result, sender: self)
        }
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
