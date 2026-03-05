///
/// ControllerGuideDetailView.swift
/// PVUI
///
/// Full-screen detail view listing every supported controller with pairing steps.
///

import SwiftUI
import PVThemes

/// Full-page guide showing all supported controllers and pairing steps.
public struct ControllerGuideDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var expandedID: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                RetroTheme.retroBackground
                    .ignoresSafeArea()

                RetroGridPattern()
                    .opacity(0.15)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        headerSection
                        ForEach(ControllerGuideInfo.all) { controller in
                            controllerRow(controller)
                        }
                        footerNote
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Controller Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.retroPink)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.retroPink)
                .shadow(color: Color.retroPink.opacity(0.7), radius: 8)

            Text("SUPPORTED CONTROLLERS")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            Text("Tap a controller to see pairing steps.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 12)
    }

    private var footerNote: some View {
        Text("After pairing, open Provenance > Settings > Controllers to assign players and customize button mappings.")
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.white.opacity(0.45))
            .multilineTextAlignment(.center)
            .padding(.top, 8)
            .padding(.bottom, 24)
    }

    // MARK: - Row

    @ViewBuilder
    private func controllerRow(_ controller: ControllerGuideInfo) -> some View {
        let isExpanded = expandedID == controller.id

        VStack(spacing: 0) {
            // Header row – always visible
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    expandedID = isExpanded ? nil : controller.id
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: controller.symbolName)
                        .font(.system(size: 22))
                        .foregroundStyle(isExpanded ? Color.retroPink : Color.retroBlue)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(controller.name)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(controller.tagline)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.retroBlue)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse \(controller.name)" : "Expand \(controller.name)")
            .accessibilityHint(isExpanded ? "Hides pairing steps" : "Shows pairing steps")

            // Expandable pairing steps
            if isExpanded {
                Divider()
                    .background(Color.retroBlue.opacity(0.4))

                VStack(alignment: .leading, spacing: 10) {
                    Text("PAIRING STEPS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.retroBlue)
                        .padding(.bottom, 2)

                    ForEach(controller.pairingSteps) { step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(step.id)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.retroPink)
                                .frame(width: 18, alignment: .center)
                                .padding(.top, 1)

                            Text(step.description)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.retroDarkBlue.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: isExpanded
                                    ? [Color.retroPink, Color.retroBlue]
                                    : [Color.retroBlue.opacity(0.5), Color.retroPurple.opacity(0.5)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isExpanded ? 1.5 : 1
                        )
                )
        )
        .shadow(color: isExpanded ? Color.retroPink.opacity(0.25) : .clear, radius: 6)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
    }
}

#if DEBUG
#Preview {
    ControllerGuideDetailView()
}
#endif
