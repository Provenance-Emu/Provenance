//
//  LogExportSheet.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/30/26.
//  Copyright 2025 Provenance Emu. All rights reserved.
//
//  A sheet that lets the user choose what to include when exporting logs,
//  then triggers a native share sheet with the resulting file.

import SwiftUI
import PVLogging

#if canImport(UIKit)
import UIKit
#endif

/// Sheet for configuring and triggering a log export.
public struct LogExportSheet: View {
    // MARK: - Properties

    @ObservedObject var viewModel: RetroLogViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var includeAppLogs = true
    @State private var includeDeviceInfo = true
    @State private var includeRetroArchLogs = true
    @State private var exportFormat: ExportFormat = .text
    @State private var isExporting = false
    @State private var exportError: String?
#if !os(tvOS)
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
#endif

    public enum ExportFormat: String, CaseIterable {
        case text = "Text File (.txt)"
        case zip = "Zip Bundle (.zip)"
    }

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
                        // Format picker
                        formatSection

                        // Include options
                        includeSection

                        // Summary
                        summarySection

                        // Export button
                        exportButton
                    }
                    .padding()
                }
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
#if !os(tvOS)
        .sheet(isPresented: $showingShareSheet) {
            if !shareItems.isEmpty {
                ShareSheetView(activityItems: shareItems)
                    .ignoresSafeArea()
            }
        }
#endif
    }

    // MARK: - Sections

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FORMAT")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(RetroTheme.retroPink.opacity(0.8))

            ForEach(ExportFormat.allCases, id: \.self) { format in
                Button {
                    exportFormat = format
                } label: {
                    HStack {
                        Image(systemName: exportFormat == format ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(exportFormat == format ? RetroTheme.retroPink : .gray)
                        Text(format.rawValue)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        if format == .zip {
                            Text("Recommended")
                                .font(.system(size: 10))
                                .foregroundColor(RetroTheme.retroBlue)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(exportFormat == format ? Color.white.opacity(0.05) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(exportFormat == format ? RetroTheme.retroPink : Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var includeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INCLUDE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(RetroTheme.retroPink.opacity(0.8))

            retroToggleRow(
                label: "App Logs (\(viewModel.displayedLogs.count) entries)",
                icon: "doc.text",
                isOn: $includeAppLogs
            )

            retroToggleRow(
                label: "Device & App Info",
                icon: "info.circle",
                isOn: $includeDeviceInfo
            )

            if exportFormat == .zip {
                retroToggleRow(
                    label: viewModel.retroArchLogsDirectory != nil
                        ? "RetroArch Logs"
                        : "RetroArch Logs (none found)",
                    icon: "gamecontroller",
                    isOn: $includeRetroArchLogs
                )
                .disabled(viewModel.retroArchLogsDirectory == nil)
                .opacity(viewModel.retroArchLogsDirectory == nil ? 0.4 : 1)
            }
        }
    }

    private var summarySection: some View {
        let count = viewModel.displayedLogs.count
        let total = viewModel.logs.count
        let hasFilter = count != total
        return VStack(alignment: .leading, spacing: 6) {
            Text("SUMMARY")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(RetroTheme.retroPink.opacity(0.8))

            Text("\(count) log entries" + (hasFilter ? " (filtered from \(total))" : ""))
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

    private var exportButton: some View {
        VStack(spacing: 8) {
            if let errorMsg = exportError {
                Text(errorMsg)
                    .font(.system(size: 12))
                    .foregroundColor(RetroTheme.retroPink)
                    .multilineTextAlignment(.center)
            }

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
                    Text(isExporting ? "Preparing…" : "Export & Share")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        colors: [RetroTheme.retroPink, RetroTheme.retroBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(isExporting || (!includeAppLogs && !includeDeviceInfo && !includeRetroArchLogs))
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func retroToggleRow(label: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(RetroTheme.retroBlue)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .foregroundColor(isOn.wrappedValue ? RetroTheme.retroPink : .gray)
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
        .buttonStyle(.plain)
    }

    private func performExport() {
        isExporting = true
        exportError = nil

        let options = RetroLogViewModel.LogExportOptions(
            includeAppLogs: includeAppLogs,
            includeDeviceInfo: includeDeviceInfo,
            includeRetroArchLogs: includeRetroArchLogs && exportFormat == .zip
        )

        let url: URL?
        switch exportFormat {
        case .text:
            url = viewModel.exportLogsAsText(options: options)
        case .zip:
            url = viewModel.exportLogsAsZip(options: options)
        }

        isExporting = false
        guard let url else {
            exportError = "Failed to create export file."
            return
        }
#if !os(tvOS)
        shareItems = [url]
        showingShareSheet = true
#endif
    }
}

// MARK: - UIActivityViewController wrapper (iOS only)

#if !os(tvOS)
private struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Preview

#if DEBUG
#Preview {
    LogExportSheet(viewModel: RetroLogViewModel())
        .preferredColorScheme(.dark)
}
#endif
