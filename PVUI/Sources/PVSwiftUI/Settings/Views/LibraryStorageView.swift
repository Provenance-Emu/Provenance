//
//  LibraryStorageView.swift
//  PVSwiftUI
//
//  Settings › Library › Storage Location: App storage, iCloud Drive, or a folder the user picks in Files.
//  Every decision lives in `LibraryStorageViewModel`; this file is layout only. iOS-only (tvOS has no picker).
//

#if !os(tvOS)
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PVLibrary
import PVThemes
import PVUIBase

struct LibraryStorageView: View {
    @State private var model = LibraryStorageViewModel()
    @State private var showsPicker = false
    @State private var showsRecoveryPicker = false

    var body: some View {
        ZStack {
            RetroSettingsBackground()

            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    currentLocationCard
                    if model.launchState.isUnavailable { recoveryCard }
                    chooseLocationCard
                    if model.location == .pickedFolder { rescanCard }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Storage Location")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsPicker) { LibraryFolderPicker { model.folderPicked($0) } }
        .sheet(isPresented: $showsRecoveryPicker) { LibraryFolderPicker { model.rebind(to: $0) } }
        .sheet(isPresented: Binding(get: { if case .confirming = model.step { return true }; return false },
                                    set: { if !$0 { model.dismissConfirmation() } })) {
            LibraryMoveConfirmationSheet(model: model)
        }
        .overlay { stepOverlay }
        .alert("Library moved", isPresented: Binding(get: { model.step == .relaunchRequired },
                                                      set: { if !$0 { model.acknowledge() } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Quit and reopen Provenance to finish. The old files are removed on the next launch.")
        }
        .alert("Couldn't move the library", isPresented: Binding(get: { if case .failed = model.step { return true }; return false },
                                                                 set: { if !$0 { model.acknowledge() } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if case .failed(let message) = model.step { Text(message) }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("STORAGE LOCATION")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                                                startPoint: .leading, endPoint: .trailing))
                .padding(.top, 20)
                .shadow(color: .retroPink.opacity(0.5), radius: 10)

            Text("Where your ROMs, BIOS and System files live.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
    }

    private var currentLocationCard: some View {
        storageCard {
            VStack(alignment: .leading, spacing: 12) {
                storageSectionLabel("Current location")
                SettingsRow(title: model.locationTitle, subtitle: model.locationDetail, icon: .sfSymbol("folder"), showChevron: false)
                if model.hasPendingMove {
                    Text("A move is waiting for a relaunch. Quit and reopen Provenance to finish it.")
                        .font(.footnote)
                        .foregroundColor(.yellow)
                }
            }
        }
    }

    private var recoveryCard: some View {
        storageCard {
            VStack(alignment: .leading, spacing: 12) {
                storageSectionLabel("Library folder unavailable")
                RetroSettingsActionButton(title: "Choose Folder…", icon: "folder.badge.plus", color: .retroBlue) {
                    showsRecoveryPicker = true
                }
                RetroSettingsActionButton(title: "Use App Storage", icon: "iphone", color: .retroPink) { model.abandon() }
                Text("Your games stay in the library and show as missing until the folder is back or you rescan.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var chooseLocationCard: some View {
        storageCard {
            VStack(alignment: .leading, spacing: 12) {
                storageSectionLabel("Choose a location")
                Button { showsPicker = true } label: {
                    SettingsRow(title: "Choose a folder…", subtitle: "Share ROMs and BIOS files with iCube and iFly through a folder in Files.",
                                icon: .sfSymbol("folder.badge.plus"))
                }
                .buttonStyle(.plain)
                .disabled(!model.canChooseFolder || model.hasPendingMove)
                Button { model.moveToAppStorage() } label: {
                    SettingsRow(title: "Use App storage", subtitle: "Copy the library back into On My iPhone › Provenance.",
                                icon: .sfSymbol("iphone"))
                }
                .buttonStyle(.plain)
                .disabled(!model.canMoveToAppStorage || model.hasPendingMove)
                NavigationLink(destination: CloudSyncSettingsView()) {
                    SettingsRow(title: "iCloud Drive", subtitle: "Managed in Cloud Sync Settings.", icon: .sfSymbol("icloud"))
                }
                .buttonStyle(.plain)
                Text("Core settings files always stay in On My iPhone › Provenance.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var rescanCard: some View {
        storageCard {
            Button { NotificationCenter.default.post(name: .PVReimportLibrary, object: nil) } label: {
                SettingsRow(title: "Rescan Library", subtitle: "Pick up files other apps added to or removed from the folder.",
                            icon: .sfSymbol("arrow.clockwise"))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var stepOverlay: some View {
        switch model.step {
        case .inspecting:
            HStack(spacing: 12) {
                ProgressView().tint(.retroPink)
                Text("Checking folder…").font(.caption)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        case .moving(let progress):
            LibraryMoveProgressOverlay(progress: progress, cancel: model.cancel)
        default:
            EmptyView()
        }
    }
}

// MARK: - Card styling (mirrors BackupRestoreView)

/// Not named `retroCard`: a free function of that name would be shadowed by `View.retroCard(opacity:)` inside any view.
@ViewBuilder
private func storageCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        content()
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.4))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(LinearGradient(gradient: Gradient(colors: [.retroPink.opacity(0.4), .retroBlue.opacity(0.4)]),
                                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                                  lineWidth: 1)
            )
    )
}

private func storageSectionLabel(_ text: String) -> some View {
    Text(text.uppercased())
        .font(.system(size: 13, weight: .bold, design: .monospaced))
        .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.retroBlue, .retroPurple]), startPoint: .leading, endPoint: .trailing))
        .padding(.bottom, 4)
}

// MARK: - Folder picker

/// `UIDocumentPickerViewController(forOpeningContentTypes: [.folder])`: returns a security-scoped URL.
private struct LibraryFolderPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            // The inspector probes the folder before the coordinator makes the bookmark (which also starts access),
            // so access has to start here. Never stopped: the folder may become the library root for the process.
            _ = url.startAccessingSecurityScopedResource()
            onPick(url)
        }
    }
}

// MARK: - Confirmation

/// What will move, the space it needs, the saves toggle, and the warnings for the folder kind (D16).
private struct LibraryMoveConfirmationSheet: View {
    @Bindable var model: LibraryStorageViewModel

    var body: some View {
        if case .confirming(let inspection, let preview) = model.step {
            NavigationStack {
                List {
                    SwiftUI.Section(inspection.hasManifest ? "Join this library" : "Move the library") {
                        Text(inspection.url.lastPathComponent).font(.headline)
                        Text(inspection.hasManifest
                             ? "This folder is already a Provenance library. Your files are added to it; files it already has are not copied twice."
                             : "ROMs, BIOS and System files move into this folder.")
                        LabeledContent("Files", value: "\(preview.fileCount)")
                        LabeledContent("Needs", value: ByteCountFormatter.string(fromByteCount: preview.requiredBytes, countStyle: .file))
                        LabeledContent("Free", value: ByteCountFormatter.string(fromByteCount: preview.availableBytes, countStyle: .file))
                    }
                    SwiftUI.Section {
                        ThemedToggle(isOn: $model.includeSaves) {
                            SettingsRow(title: "Also move saves",
                                        subtitle: "Save states, battery saves, screenshots, cheats and patches. Off by default: other apps' cores use different formats.",
                                        showChevron: false)
                        }
                        .disabled(model.includeSavesIsLocked)
                        .onChange(of: model.includeSaves) { model.refreshPreview() }
                    }
                    if inspection.kind == .otherAppDocuments {
                        SwiftUI.Section { Text("This folder belongs to another app. It disappears if that app is deleted.").foregroundStyle(.orange) }
                    }
                    if inspection.kind == .iCloudDrive {
                        SwiftUI.Section { Text("Files in iCloud Drive may need to download before a game can start.") }
                    }
                    if !preview.fits {
                        SwiftUI.Section { Text("Not enough free space in this folder.").foregroundStyle(.red) }
                    }
                }
                .navigationTitle("Storage Location")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.dismissConfirmation() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(inspection.hasManifest ? "Join" : "Move") { model.confirmMove() }.disabled(!preview.fits)
                    }
                }
            }
        }
    }
}

// MARK: - Progress

private struct LibraryMoveProgressOverlay: View {
    let progress: LibraryMoveProgress
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: progress.fraction)
            Text(progress.currentPath ?? "Preparing…").font(.footnote).lineLimit(1)
            Text("\(progress.filesDone) of \(progress.filesTotal) files")
            if progress.phase == .copying {
                Button("Cancel", role: .cancel, action: cancel)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }
}

// MARK: - Launch alert

/// Shown once per launch, from `MainView`, when the stored picked folder could not be opened (D9).
struct LibraryFolderUnavailableAlert: ViewModifier {
    @State private var isPresented = LibraryLocation.pickedFolderAtLaunch.isUnavailable
    @State private var showsPicker = false
    @State private var showsRelaunch = false
    @State private var model = LibraryStorageViewModel()

    func body(content: Content) -> some View {
        content
            .alert("Library folder unavailable", isPresented: $isPresented) {
                Button("Choose Folder…") { showsPicker = true }
                Button("Use App Storage") { model.abandon(); showsRelaunch = model.step == .relaunchRequired }
                Button("Later", role: .cancel) {}
            } message: {
                if case .unavailable(let reason) = LibraryLocation.pickedFolderAtLaunch { Text(reason) }
            }
            .sheet(isPresented: $showsPicker) { LibraryFolderPicker { model.rebind(to: $0); showsRelaunch = model.step == .relaunchRequired } }
            .alert("Relaunch required", isPresented: $showsRelaunch) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Quit and reopen Provenance to use the new location.")
            }
    }
}
#endif
