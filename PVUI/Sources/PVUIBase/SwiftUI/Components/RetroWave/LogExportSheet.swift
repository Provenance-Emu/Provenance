//
//  LogExportSheet.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/30/26.
//  Copyright 2025 Provenance Emu. All rights reserved.
//
//  A sheet that lets the user choose what to include when exporting logs,
//  then shares the result (iOS) or writes it where WebDAV can serve it (tvOS).

import SwiftUI
import PVLogging

/// Sheet for configuring and triggering a log export.
public struct LogExportSheet: View {
    // MARK: - Properties

    @ObservedObject var viewModel: RetroLogViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var options = LogExportOptions()
    @State private var sources = LogExportSourceSet()
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportResult: LogExportResult?

    private static let formatLabels: [LogExportOptions.Format: String] = [
        .text: "Text File (.log)",
        .zip: "Zip Bundle (.zip)"
    ]

    public init(viewModel: RetroLogViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        formatSection
                        includeSection
                        summarySection
                        actionSection
                    }
                    .padding()
                }
                // Any change to what is included invalidates a file already written.
                .onChange(of: options) { _, _ in exportResult = nil }
            }
            .navigationTitle("Export Logs")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(RetroTheme.retroPink)
                }
            }
        }
        .onAppear { sources = viewModel.availableExportSources }
        #if os(tvOS)
        .onExitCommand { dismiss() }
        #endif
    }

    // MARK: - Sections

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("FORMAT")

            ForEach(LogExportOptions.Format.allCases, id: \.self) { format in
                LogExportFormatRow(
                    title: Self.formatLabels[format] ?? format.rawValue,
                    badge: format == .zip ? "Recommended" : nil,
                    isSelected: options.format == format
                ) {
                    options.format = format
                }
            }
        }
    }

    private var includeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("INCLUDE")

            LogExportToggleRow(
                label: "App Logs (\(viewModel.displayedLogs.count) entries)",
                icon: "doc.text",
                isOn: $options.includeAppLogs
            )

            LogExportToggleRow(
                label: "Device & App Info",
                icon: "info.circle",
                isOn: $options.includeDeviceInfo
            )

            LogExportToggleRow(
                label: countedLabel("Session Log Files", count: sources.sessionFiles.count),
                icon: "doc.on.doc",
                isOn: $options.includeSessionFiles,
                available: !sources.sessionFiles.isEmpty
            )

            LogExportToggleRow(
                label: countedLabel("Crash Reports", count: sources.crashReports.count),
                icon: "exclamationmark.triangle",
                isOn: $options.includeCrashReports,
                available: !sources.crashReports.isEmpty
            )

            LogExportToggleRow(
                label: countedLabel("Core Logs", count: sources.coreLogs.count),
                icon: "gamecontroller",
                isOn: $options.includeCoreLogs,
                available: !sources.coreLogs.isEmpty
            )

            Text(options.format == .text
                 ? "Selected files are appended to the text export."
                 : "Selected files are copied into the bundle next to manifest.json.")
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
    }

    private var summarySection: some View {
        let count = viewModel.displayedLogs.count
        let total = viewModel.logs.count
        let hasFilter = count != total
        let fileCount = selectedFileCount
        return VStack(alignment: .leading, spacing: 6) {
            sectionTitle("SUMMARY")

            Text("\(count) log entries" + (hasFilter ? " (filtered from \(total))" : ""))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
            Text("\(fileCount) file" + (fileCount == 1 ? "" : "s") + " from disk")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    /// Export button, then the share (iOS) or location (tvOS) step once a file exists.
    private var actionSection: some View {
        VStack(spacing: 8) {
            if let errorMsg = exportError {
                Text(errorMsg)
                    .font(.system(size: 12))
                    .foregroundColor(RetroTheme.retroPink)
                    .multilineTextAlignment(.center)
            }
            if let result = exportResult {
                resultView(result)

                Button("Export again") {
                    exportResult = nil
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(RetroTheme.retroBlue)
                .retroFocusButtonStyle(cornerRadius: 6, showBorder: false)
            } else {
                Button {
                    performExport()
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isExporting ? "Preparing…" : exportButtonTitle)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(actionGradient)
                    .cornerRadius(8)
                }
                .retroFocusButtonStyle(focusScale: 1.02, cornerRadius: 8, showBorder: false)
                .disabled(isExporting || effectiveOptions.isEmpty)
            }
        }
    }

    @ViewBuilder
    private func resultView(_ result: LogExportResult) -> some View {
#if os(tvOS)
        VStack(alignment: .leading, spacing: 6) {
            Label("Export saved", systemImage: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
            Text(result.url.lastPathComponent)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
            Text("Turn on the web server in Settings and open the \"Logs/Exports\" folder over WebDAV to copy it to a computer.")
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.green.opacity(0.5), lineWidth: 1)
        )
#else
        // File ready — present the native share sheet via ShareLink.
        ShareLink(item: result.url) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share \(result.url.lastPathComponent)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .foregroundColor(.white)
            .background(actionGradient)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
#endif
    }

    // MARK: - Helpers

    private var actionGradient: LinearGradient {
        LinearGradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue], startPoint: .leading, endPoint: .trailing)
    }

    private var exportButtonTitle: String {
#if os(tvOS)
        return "Export"
#else
        return "Export & Share"
#endif
    }

    /// Options with unavailable sources switched off, so an empty folder never counts as content.
    private var effectiveOptions: LogExportOptions {
        var resolved = options
        if sources.sessionFiles.isEmpty { resolved.includeSessionFiles = false }
        if sources.crashReports.isEmpty { resolved.includeCrashReports = false }
        if sources.coreLogs.isEmpty { resolved.includeCoreLogs = false }
        return resolved
    }

    private var selectedFileCount: Int {
        let resolved = effectiveOptions
        var count = 0
        if resolved.includeSessionFiles { count += sources.sessionFiles.count }
        if resolved.includeCrashReports { count += sources.crashReports.count }
        if resolved.includeCoreLogs { count += sources.coreLogs.count }
        return count
    }

    private func countedLabel(_ base: String, count: Int) -> String {
        count == 0 ? "\(base) (none found)" : "\(base) (\(count))"
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(RetroTheme.retroPink.opacity(0.8))
    }

    @MainActor
    private func performExport() {
        guard !isExporting else { return }
        isExporting = true
        exportError = nil
        exportResult = nil

        let resolved = effectiveOptions
        let vm = viewModel

        // Export runs on the main actor so it safely reads @Published `logs`/`displayedLogs`.
        // Typical exports finish in well under a second.
        Task { @MainActor in
            defer { isExporting = false }
            do {
                exportResult = try vm.exportLogs(options: resolved)
            } catch {
                ELOG("Log export failed: \(error.localizedDescription)")
                exportError = error.localizedDescription
            }
        }
    }
}

// MARK: - Rows

/// Radio-style row for picking the output format.
private struct LogExportFormatRow: View {
    let title: String
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? RetroTheme.retroPink : .gray)
                Text(title)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 10))
                        .foregroundColor(RetroTheme.retroBlue)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.white.opacity(0.05) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isSelected ? RetroTheme.retroPink : Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .retroFocusButtonStyle(focusScale: 1.02, cornerRadius: 6, showBorder: false)
    }
}

/// Checkbox-style row for one include option; dimmed and inert when its source has no files.
private struct LogExportToggleRow: View {
    let label: String
    let icon: String
    @Binding var isOn: Bool
    var available = true

    var body: some View {
        let checked = available && isOn
        Button {
            isOn.toggle()
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(RetroTheme.retroBlue)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundColor(checked ? RetroTheme.retroPink : .gray)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .retroFocusButtonStyle(focusScale: 1.02, cornerRadius: 6, showBorder: false)
        .disabled(!available)
        .opacity(available ? 1 : 0.4)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    LogExportSheet(viewModel: RetroLogViewModel())
        .preferredColorScheme(.dark)
}
#endif
