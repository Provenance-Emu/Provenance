//
//  BezelProjectBrowserView.swift
//  PVUI
//
//  Browses The Bezel Project's artwork by system and downloads single bezels.
//

#if os(iOS)
import SwiftUI
import Defaults
import PVSettings
import PVSystems

/// One image of one repository: what the browser lists.
private struct BezelProjectItem: Identifiable, Hashable {
    let repository: BezelProjectRepository
    let entry: BezelProjectListing.Entry

    var id: String { "\(repository.name)/\(entry.path)" }
    var name: String { BezelProjectService.displayName(for: entry) }
    var isOnDevice: Bool {
        TVBezelLibrary.shared.bezel(relativePath: BezelProjectService.libraryPath(for: entry, in: repository)) != nil
    }
}

/// The Bezel Project: the credit, the style and the systems it has artwork for.
struct BezelProjectBrowserView: View {
    /// The running game, so a bezel can be used for it straight from the browser.
    var game: ExternalDisplayGameContext?
    @Default(.externalDisplayBezelProjectStyle) private var style

    private var systems: [SystemIdentifier] {
        BezelProjectService.systems.keys.compactMap(SystemIdentifier.init(rawValue:)).sorted { $0.fullName < $1.fullName }
    }

    var body: some View {
        List {
            Section {
                Text("Artwork by The Bezel Project, used with the project's permission. It is downloaded from the project's own pages when you ask for it.")
                if let url = BezelProjectRepository.projectURL {
                    Link(String(localized: "The Bezel Project on GitHub"), destination: url)
                }
            }
            Section {
                Picker(String(localized: "Style"), selection: $style) {
                    ForEach(BezelProjectStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Game Art is themed on each game. System Art is themed on the system, with the game's name. Game Bezels uses the same style.")
            }
            Section(String(localized: "Systems")) {
                ForEach(systems, id: \.rawValue) { system in
                    NavigationLink(system.fullName) {
                        BezelProjectSystemView(systemID: system.rawValue, game: game?.systemID == system.rawValue ? game : nil)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "The Bezel Project"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One system's artwork: its own bezel first, then its games, searchable.
struct BezelProjectSystemView: View {
    let systemID: String
    var game: ExternalDisplayGameContext?
    @Default(.externalDisplayBezelProjectStyle) private var style

    @State private var items: [BezelProjectItem] = []
    @State private var isLoading = true
    @State private var message: String?
    @State private var search = ""
    @State private var usage: (bezels: Int, bytes: Int) = (0, 0)

    private var repositories: [BezelProjectRepository] {
        BezelProjectService.repositories(systemID: systemID, style: style)
    }

    private var shown: [BezelProjectItem] {
        let wanted = search.trimmingCharacters(in: .whitespaces)
        guard !wanted.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(wanted) }
    }

    var body: some View {
        List {
            if let message {
                Section { Text(message).foregroundStyle(.secondary) }
            }
            if usage.bezels > 0 {
                Section {
                    LabeledContent(String(localized: "On This Device"),
                                   value: String(localized: "\(usage.bezels) bezels, \(Int64(usage.bytes).formatted(.byteCount(style: .file)))"))
                    Button(String(localized: "Delete Downloads"), role: .destructive) {
                        repositories.map(BezelProjectService.libraryFolder(for:)).forEach(TVBezelLibrary.shared.deleteFolder(relativePath:))
                    }
                } footer: {
                    Text("Bezels you added to My Bezels are deleted too.")
                }
            }
            Section {
                ForEach(shown) { item in
                    NavigationLink {
                        BezelProjectEntryView(item: item, systemID: systemID, game: game)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                if item.entry.kind == .system {
                                    Text("The system's bezel").font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if item.isOnDevice {
                                Image(systemName: "arrow.down.circle.fill").foregroundStyle(.secondary)
                                    .accessibilityLabel(String(localized: "Downloaded"))
                            }
                        }
                    }
                }
            } header: {
                if isLoading {
                    ProgressView()
                } else if !items.isEmpty {
                    Text("\(shown.count) bezels")
                }
            }
        }
        .searchable(text: $search, prompt: String(localized: "Game"))
        .navigationTitle(SystemIdentifier(rawValue: systemID)?.systemName ?? String(localized: "Bezels"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: style) { await load(forceRefresh: false) }
        .refreshable { await load(forceRefresh: true) }
        .onReceive(NotificationCenter.default.publisher(for: TVBezelLibrary.didChangeNotification)) { _ in
            updateUsage()
        }
    }

    private func load(forceRefresh: Bool) async {
        isLoading = true
        message = nil
        var loaded: [BezelProjectItem] = []
        var failure: String?
        for repository in repositories {
            do {
                let listing = try await BezelProjectService.shared.listing(for: repository, forceRefresh: forceRefresh)
                loaded += listing.entries.map { BezelProjectItem(repository: repository, entry: $0) }
            } catch {
                failure = (error as? BezelProjectService.ServiceError)?.message ?? error.localizedDescription
            }
        }
        // The system's own bezels first, then games by name.
        items = loaded.sorted { first, second in
            let (firstIsSystem, secondIsSystem) = (first.entry.kind == .system, second.entry.kind == .system)
            if firstIsSystem != secondIsSystem { return firstIsSystem }
            return first.name.localizedStandardCompare(second.name) == .orderedAscending
        }
        if items.isEmpty {
            message = failure ?? String(localized: "The Bezel Project has no \(style.displayName) bezels for this system.")
        } else {
            message = failure
        }
        isLoading = false
        updateUsage()
    }

    private func updateUsage() {
        usage = repositories.map { TVBezelLibrary.shared.usage(relativePath: BezelProjectService.libraryFolder(for: $0)) }
            .reduce((0, 0)) { ($0.0 + $1.count, $0.1 + $1.bytes) }
    }
}

/// One bezel: downloaded when opened, shown, and added or used from here.
private struct BezelProjectEntryView: View {
    let item: BezelProjectItem
    let systemID: String
    var game: ExternalDisplayGameContext?

    @Default(.externalDisplayBezelByGame) private var pins
    @Default(.externalDisplayBezel) private var chosen
    @State private var bezel: TVBezel?
    @State private var preview: UIImage?
    @State private var message: String?

    private static let previewPixels: CGFloat = 1280

    var body: some View {
        Form {
            Section {
                if let preview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .background(Color.black)
                        .accessibilityLabel(String(localized: "Preview of \(item.name)"))
                } else if let message {
                    Text(message).foregroundStyle(.secondary)
                } else {
                    HStack {
                        ProgressView()
                        Text("Downloading \(Int64(item.entry.size).formatted(.byteCount(style: .file)))…").foregroundStyle(.secondary)
                    }
                }
            }
            if let bezel {
                Section {
                    if let game {
                        Button(pins[game.md5] == bezel.id ? String(localized: "Used for This Game") : String(localized: "Use for This Game")) {
                            pins[game.md5] = bezel.id
                        }
                        .disabled(pins[game.md5] == bezel.id)
                    }
                    Button(bezel.isListed ? String(localized: "In My Bezels") : String(localized: "Add to My Bezels")) {
                        Task { await fetch(listed: true) }
                    }
                    .disabled(bezel.isListed)
                    if bezel.isListed {
                        Button(chosen == bezel.id ? String(localized: "This Is Your TV") : String(localized: "Use as Your TV")) {
                            chosen = bezel.id
                        }
                        .disabled(chosen == bezel.id)
                    }
                } footer: {
                    if item.entry.kind == .system {
                        Text("In My Bezels, a system's bezel is used for that system's games while Match the System's Screen is on.")
                    }
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await fetch(listed: false) }
    }

    private func fetch(listed: Bool) async {
        do {
            let fetched = try await BezelProjectService.shared.bezel(for: item.entry, in: item.repository, systemID: systemID, listed: listed)
            bezel = fetched
            guard preview == nil, let url = fetched.image?.fileURL else { return }
            preview = await Task.detached(priority: .userInitiated) {
                TVBezelImage.displayImage(url, maxPixel: Self.previewPixels).map { UIImage(cgImage: $0) }
            }.value
        } catch {
            message = (error as? BezelProjectService.ServiceError)?.message ?? error.localizedDescription
        }
    }
}
#endif
