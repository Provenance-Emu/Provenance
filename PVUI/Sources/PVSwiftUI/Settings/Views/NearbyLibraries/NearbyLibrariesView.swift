//
//  NearbyLibrariesView.swift
//  PVSwiftUI
//
//  Settings › Library › Nearby Libraries: iFly and iCube libraries on the
//  local network, a browser for each, and copying a game into the library.
//

#if os(iOS) || os(tvOS)
import PVLibrarySharing
import PVSystems
import SwiftUI

struct NearbyLibrariesView: View {
    @State private var model = NearbyLibrariesModel()
    #if os(tvOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    var body: some View {
        List {
            SwiftUI.Section {
                NavigationLink {
                    LibrarySharingSettingsView()
                } label: {
                    Label("Share This Library", systemImage: "square.and.arrow.up.on.square")
                }
            }

            SwiftUI.Section {
                if model.visiblePeers.isEmpty {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Looking for libraries on this network…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(model.visiblePeers) { peer in
                        NavigationLink {
                            NearbyPeerLibraryView(model: model.peerModel(for: peer))
                        } label: {
                            NearbyPeerRow(peer: peer, summary: model.loadedSummaries[peer.id])
                        }
                    }
                }
            } footer: {
                Text("Turn on Library Sharing in iFly, iCube or Provenance on another device on the same Wi-Fi. "
                     + "Copied games are imported into your library; BIOS files and saves stay on the other device.")
            }

            if model.snapshot.localNetworkDenied {
                SwiftUI.Section {
                    Label("Provenance can't see the local network.", systemImage: "wifi.exclamationmark")
                    #if os(iOS)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    #endif
                } footer: {
                    Text("Allow Local Network access for Provenance in Settings › Privacy & Security › Local Network.")
                }
            }

            ForEach(model.browseProblems) { problem in
                SwiftUI.Section {
                    Label(problem.message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Nearby Libraries")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        #if os(tvOS)
        .onExitCommand { dismiss() }
        #endif
        .settingsSubpageTracking()
    }
}

private struct NearbyPeerRow: View {
    let peer: DiscoveredPeer
    let summary: String?

    static func symbol(for app: PeerApp) -> String {
        switch app {
        case .iFly: return "opticaldisc"
        case .iCube: return "cube"
        case .pvLibrary: return "books.vertical"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: Self.symbol(for: peer.app))
                .font(.title2)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(peer.serviceName)
                    .font(.body)
                Text(summary ?? "\(peer.appDisplayName) · Tap to browse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(peer.appDisplayName)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.accentColor.opacity(0.2)))
        }
        .padding(.vertical, 4)
    }
}

struct NearbyPeerLibraryView: View {
    let model: NearbyPeerLibraryModel
    @State private var code = ""

    var body: some View {
        List {
            switch model.phase {
            case .idle, .loading:
                SwiftUI.Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(progressText)
                            .foregroundStyle(.secondary)
                    }
                }
            case .needsPairing:
                pairingPrompt
            case .enteringCode(let handle):
                codeEntry(handle)
            case .confirmingCode:
                SwiftUI.Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Approve the pairing on \(model.title)…")
                            .foregroundStyle(.secondary)
                    }
                }
            case .failed(let message):
                SwiftUI.Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                    Button("Try Again") { model.load() }
                }
            case .loaded:
                catalogueSections
            }
        }
        .navigationTitle(model.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if model.phase == .idle { model.load() }
        }
        .onDisappear { model.cancel() }
        .settingsSubpageTracking()
    }

    private var progressText: String {
        switch model.phase {
        case .loading(.waitingForApproval):
            return "Waiting for approval on \(model.title)…"
        case .loading(.loadingCatalogue):
            return "Loading the library…"
        default:
            return "Connecting to \(model.title)…"
        }
    }

    @ViewBuilder
    private var catalogueSections: some View {
        if model.sections.isEmpty {
            SwiftUI.Section {
                Text("\(model.title) isn't sharing any games Provenance can play.")
                    .foregroundStyle(.secondary)
            }
        }
        ForEach(model.sections) { section in
            SwiftUI.Section(section.system.fullName) {
                ForEach(section.items) { item in
                    NearbyItemRow(
                        item: item,
                        image: model.artwork[item.id],
                        inLibrary: model.isInLibrary(item),
                        copyState: model.copies[item.id],
                        peerName: model.title,
                        onCopy: { model.copy(item) },
                        onCancel: { model.cancelCopy(item) }
                    )
                    .task(id: item.id) { await model.loadArtwork(for: item) }
                }
            }
        }
        if model.unsupportedCount > 0 {
            SwiftUI.Section {
                Text("\(model.unsupportedCount) more game\(model.unsupportedCount == 1 ? " isn't" : "s aren't") supported by Provenance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pairingPrompt: some View {
        SwiftUI.Section {
            Button("Pair with \(model.title)") { model.beginPairing() }
        } footer: {
            Text("iCube shares its library only with paired devices. A 6-digit code will appear on \(model.title).")
        }
    }

    private func codeEntry(_ handle: ICubePairingHandle) -> some View {
        SwiftUI.Section {
            TextField("6-digit code", text: $code)
                #if os(iOS)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                #endif
            Button("Pair") {
                model.submitCode(code.trimmingCharacters(in: .whitespaces), for: handle)
                code = ""
            }
            .disabled(code.trimmingCharacters(in: .whitespaces).count != 6)
        } header: {
            Text("Enter the code shown on \(handle.serverName)")
        } footer: {
            if let error = model.codeError {
                Text(error).foregroundStyle(.red)
            } else {
                Text("Then approve the request on \(handle.serverName).")
            }
        }
    }
}

private struct NearbyItemRow: View {
    let item: RemoteLibraryItem
    let image: UIImage?
    let inLibrary: Bool
    let copyState: NearbyCopyState?
    let peerName: String
    let onCopy: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .lineLimit(2)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(isFailure ? Color.red : Color.secondary)
                    .lineLimit(3)
                if case .downloading(let fraction) = copyState {
                    ProgressView(value: fraction)
                }
            }
            Spacer()
            trailing
                #if os(iOS)
                .buttonStyle(.borderless)
                #endif
        }
    }

    private var isFailure: Bool {
        if case .failed = copyState { return true }
        return false
    }

    private var detail: String {
        let size = ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file)
        switch copyState {
        case .preparing(.waitingForApproval):
            return "Waiting for approval on \(peerName)…"
        case .preparing:
            return "Connecting…"
        case .downloading(let fraction):
            return "Copying… \(Int(fraction * 100))% of \(size)"
        case .verifying:
            return "Checking the copy…"
        case .importing:
            return "Copied. Importing into your library…"
        case .failed(let message):
            return message
        case nil:
            return size
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if copyState?.isActive == true {
            Button("Stop", role: .cancel, action: onCancel)
        } else if copyState == .importing {
            Image(systemName: "tray.and.arrow.down.fill")
                .foregroundStyle(.secondary)
        } else if inLibrary {
            Label("In your library", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .foregroundStyle(.green)
        } else {
            Button(isFailure ? "Retry" : "Copy", action: onCopy)
        }
    }
}
#endif
