//
//  AchievementToastView.swift
//  PVUIBase
//
//  In-game OSD overlay for RetroAchievements notifications.
//
//  Usage (from PVEmulatorViewController+Achievements.swift):
//    achievementOverlayController = AchievementOverlayViewController()
//    addChild(achievementOverlayController)
//    view.addSubview(achievementOverlayController.view)
//    achievementOverlayController.view.frame = view.bounds
//    achievementOverlayController.didMove(toParent: self)
//
//    // Then forward OSD delegate calls:
//    achievementOverlayController.showUnlock(notification)
//

import SwiftUI
import PVCheevos
import PVCoreBridge

// MARK: - Toast model

private struct AchievementToast: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    let points: UInt32
    let badgeURL: URL?
    let isHardcore: Bool
}

// MARK: - Overlay ViewModel

@MainActor
final class AchievementOverlayViewModel: ObservableObject {
    @Published fileprivate var toasts: [AchievementToast] = []
    @Published fileprivate var challengeIndicators: [UInt32: URL?] = [:]

    func enqueue(unlock: AchievementUnlockNotification) {
        let toast = AchievementToast(
            title: unlock.title,
            description: unlock.description,
            points: unlock.points,
            badgeURL: unlock.badgeURL,
            isHardcore: unlock.isHardcore
        )
        toasts.append(toast)

        // Auto-dismiss after 4 seconds
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            toasts.removeAll { $0.id == toast.id }
        }
    }

    func showChallenge(_ notification: AchievementChallengeNotification) {
        challengeIndicators[notification.achievementID] = notification.badgeURL
    }

    func hideChallenge(achievementID: UInt32) {
        challengeIndicators.removeValue(forKey: achievementID)
    }
}

// MARK: - Root overlay view

struct AchievementOverlayView: View {
    @ObservedObject var viewModel: AchievementOverlayViewModel

    var body: some View {
        ZStack {
            // Toast stack — top-right corner
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(viewModel.toasts) { toast in
                    AchievementToastCardView(toast: toast)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
                Spacer()
            }
            .padding(.top, 20)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.toasts)

            // Challenge indicators — bottom-left corner
            if !viewModel.challengeIndicators.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(Array(viewModel.challengeIndicators.keys.sorted().prefix(5)), id: \.self) { achID in
                            ChallengeIndicatorView(badgeURL: viewModel.challengeIndicators[achID] ?? nil)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut, value: viewModel.challengeIndicators.count)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Individual toast card

private struct AchievementToastCardView: View {
    let toast: AchievementToast

    var body: some View {
        HStack(spacing: 12) {
            // Badge / trophy icon
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .strokeBorder(hardcoreBorderGradient, lineWidth: toast.isHardcore ? 2 : 1)
                    )

                if let url = toast.badgeURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                                .clipShape(Circle())
                        default:
                            trophyIcon
                        }
                    }
                    .frame(width: 38, height: 38)
                } else {
                    trophyIcon
                }
            }

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement Unlocked")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(0.5)

                Text(toast.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(titleGradient)
                    .lineLimit(1)

                Text(toast.description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
            }

            // Points badge
            VStack {
                Text("+\(toast.points)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(titleGradient)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(hardcoreBorderGradient, lineWidth: 1)
                )
        )
        .shadow(color: glowColor.opacity(0.5), radius: 8, x: 0, y: 2)
        .frame(maxWidth: 300)
    }

    private var trophyIcon: some View {
        Image(systemName: toast.isHardcore ? "trophy.fill" : "star.fill")
            .font(.system(size: 20))
            .foregroundStyle(titleGradient)
    }

    private var titleGradient: LinearGradient {
        LinearGradient(
            colors: toast.isHardcore
                ? [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.0)]
                : [Color(red: 1.0, green: 0.27, blue: 0.73), Color(red: 0.43, green: 0.31, blue: 1.0)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var hardcoreBorderGradient: LinearGradient {
        LinearGradient(
            colors: toast.isHardcore
                ? [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.0)]
                : [Color(red: 1.0, green: 0.27, blue: 0.73).opacity(0.6), Color(red: 0.43, green: 0.31, blue: 1.0).opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var glowColor: Color {
        toast.isHardcore ? Color(red: 1.0, green: 0.84, blue: 0.0) : Color(red: 1.0, green: 0.27, blue: 0.73)
    }
}

// MARK: - Challenge indicator badge

private struct ChallengeIndicatorView: View {
    let badgeURL: URL?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.75))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .strokeBorder(Color.yellow.opacity(0.8), lineWidth: 1.5)
                )

            if let url = badgeURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit().clipShape(Circle())
                    } else {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.yellow)
                    }
                }
                .frame(width: 26, height: 26)
            } else {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
            }
        }
    }
}

// MARK: - UIKit host controller

/// A UIViewController that hosts the SwiftUI achievement overlay.
/// Add it as a child of `PVEmulatorViewController` so it floats above the GPU view.
@MainActor
public final class AchievementOverlayViewController: UIViewController {

    public let overlayViewModel = AchievementOverlayViewModel()
    private var hostingController: UIHostingController<AchievementOverlayView>?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false

        let overlayView = AchievementOverlayView(viewModel: overlayViewModel)
        let host = UIHostingController(rootView: overlayView)
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false

        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hostingController = host
    }

    // MARK: - Public interface (called from OSD delegate)

    public func showUnlock(_ notification: AchievementUnlockNotification) {
        overlayViewModel.enqueue(unlock: notification)
    }

    public func showChallengeIndicator(_ notification: AchievementChallengeNotification) {
        overlayViewModel.showChallenge(notification)
    }

    public func hideChallengeIndicator(achievementID: UInt32) {
        overlayViewModel.hideChallenge(achievementID: achievementID)
    }
}
