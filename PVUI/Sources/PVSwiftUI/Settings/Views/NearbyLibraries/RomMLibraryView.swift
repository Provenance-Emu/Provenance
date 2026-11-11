#if os(iOS) || os(tvOS)
import PVLibrary
import PVSystems
import RomMClient
import SwiftUI

@MainActor
struct RomMLibraryView: View {
    @AppStorage("RomM.lastServer") private var lastServer = ""
    @State private var address = ""
    @State private var token = ""
    @State private var username = ""
    @State private var password = ""
    @State private var usePassword = false
    @State private var saveLogin = true
    @State private var attemptedRestore = false
    @State private var allowHTTP = false
    @State private var client: RomMClient?
    @State private var platforms: [RomMPlatform] = []
    @State private var platformID: Int?
    @State private var games: [RomMGame] = []
    @State private var imported: Set<Int> = []
    @State private var nextOffset: Int?
    @State private var search = ""
    @State private var appliedSearch = ""
    @State private var operation: Task<Void, Never>?
    @State private var errorMessage: String?

    private var server: RomMAddress? { try? RomMAddress(address) }
    private var busy: Bool { operation != nil }

    var body: some View {
        List {
            if client == nil {
                SwiftUI.Section("RomM Server") {
                    TextField("Server address", text: $address)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                    Toggle("Use username and password", isOn: $usePassword)
                    if usePassword {
                        TextField("Username", text: $username)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                        SecureField("Password", text: $password)
                    } else {
                        SecureField("Client API token (optional)", text: $token)
                            .autocorrectionDisabled()
                    }
                    Toggle("Save login", isOn: $saveLogin)
                    if let server, savedLogin(for: server) != nil {
                        Button("Forget saved login", role: .destructive) {
                            run {
                                try RomMLoginStore.write(nil, server: server)
                                if lastServer == server.baseURL.absoluteString { lastServer = "" }
                            }
                        }
                    }
                    if server?.isHTTPS == false {
                        Toggle("Allow credentials over HTTP", isOn: $allowHTTP)
                    }
                    Button("Connect") { run { try await connect() } }
                        .disabled(server == nil || (usePassword && (username.isEmpty || password.isEmpty)))
                }
                .disabled(busy)
            } else {
                SwiftUI.Section {
                    if !platforms.isEmpty {
                        Picker("Platform", selection: Binding(get: { platformID }, set: { selectPlatform($0) })) {
                            ForEach(platforms) { platform in Text(platform.title).tag(Optional(platform.id)) }
                        }
                        TextField("Search games", text: $search)
                            .onSubmit(applySearch)
                        Button("Search", action: applySearch)
                    }
                    Button("Disconnect") { disconnect() }
                }
                .disabled(busy)

                SwiftUI.Section("Games") {
                    if games.isEmpty, !busy {
                        Text(platforms.isEmpty ? "No supported platforms on this server." : "No matching games.")
                            .foregroundStyle(.secondary)
                    }
                    if !imported.isEmpty {
                        Text("Downloaded games were sent to the import queue.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(games) { game in
                        Button {
                            run { try await importGame(game) }
                        } label: {
                            Label(game.title, systemImage: imported.contains(game.id) ? "checkmark.circle" : "arrow.down.circle")
                        }
                        .disabled(busy || imported.contains(game.id))
                    }
                    if let nextOffset {
                        Button("Load more") { run { try await loadPage(offset: nextOffset) } }
                            .disabled(busy)
                    }
                }
            }
            if busy {
                HStack {
                    ProgressView()
                    Button("Cancel", role: .cancel) { operation?.cancel() }
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.secondary) }
        }
        .navigationTitle("RomM")
        .onAppear(perform: restoreConnection)
        .onChange(of: address) { _, _ in allowHTTP = false }
        .onDisappear { operation?.cancel() }
    }

    private func run(_ work: @escaping @MainActor () async throws -> Void) {
        guard operation == nil else { return }
        errorMessage = nil
        operation = Task {
            defer { operation = nil }
            do {
                try await work()
            } catch {
                if !Task.isCancelled { errorMessage = error.localizedDescription }
            }
        }
    }

    private func savedLogin(for server: RomMAddress) -> RomMSavedLogin? {
        RomMLoginStore.read(server).flatMap { RomMSavedLogin(storedValue: $0) }
    }

    private func restoreConnection() {
        guard !attemptedRestore else { return }
        attemptedRestore = true
        address = lastServer
        guard let server, let login = savedLogin(for: server) else { return }
        run { try await connect(restoring: login) }
    }

    private func connect(restoring login: RomMSavedLogin? = nil) async throws {
        let server = try RomMAddress(address)
        let entered = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let credential: RomMCredential
        if let login {
            credential = login.credential
        } else if usePassword {
            credential = .basic(username: username, password: password)
        } else if !entered.isEmpty {
            credential = .token(entered)
        } else if let saved = savedLogin(for: server) {
            credential = saved.credential
        } else {
            credential = .none
        }

        let useHTTP = login?.allowHTTP ?? allowHTTP
        let candidate = try RomMClient(address: server, credential: credential, allowHTTP: useHTTP)
        let playableSystems = Set(PVSystem.all
            .filter { $0.cores.contains { !$0.disabled && $0.hasCoreClass } }
            .compactMap { SystemIdentifier(rawValue: $0.identifier) })
        let supported = try await candidate.platforms().filter { platform in
            RomMGameImport.system(for: platform).map(playableSystems.contains) ?? false
        }
        let firstID = supported.first?.id
        let firstPage: RomMPage?
        if let firstID {
            firstPage = try await candidate.games(platformID: firstID)
        } else {
            firstPage = nil
        }
        try Task.checkCancellation()
        if login == nil {
            if saveLogin {
                let saved = RomMSavedLogin(credential: credential, allowHTTP: useHTTP)
                try RomMLoginStore.write(saved.storedValue(), server: server)
                lastServer = server.baseURL.absoluteString
            } else {
                try RomMLoginStore.write(nil, server: server)
                if lastServer == server.baseURL.absoluteString { lastServer = "" }
            }
        }
        token = ""
        password = ""
        platforms = supported
        platformID = firstID
        client = candidate
        if let firstPage { append(firstPage) }
    }

    private func selectPlatform(_ id: Int?) {
        guard id != platformID else { return }
        platformID = id
        reload()
    }

    private func applySearch() {
        guard !busy else { return }
        appliedSearch = search.trimmingCharacters(in: .whitespacesAndNewlines)
        reload()
    }

    private func reload() {
        games = []
        nextOffset = nil
        run { try await loadPage(offset: 0) }
    }

    private func loadPage(offset: Int) async throws {
        guard let client, let platformID else { return }
        let page = try await client.games(platformID: platformID, search: appliedSearch, offset: offset)
        try Task.checkCancellation()
        append(page)
    }

    private func append(_ page: RomMPage) {
        var seen = Set(games.map { $0.id })
        games.append(contentsOf: page.items.filter { $0.isDownloadable && seen.insert($0.id).inserted })
        nextOffset = page.nextOffset
    }

    private func disconnect() {
        client = nil
        platforms = []
        games = []
        imported = []
        platformID = nil
        nextOffset = nil
        search = ""
        appliedSearch = ""
        allowHTTP = false
        errorMessage = nil
    }

    private func importGame(_ game: RomMGame) async throws {
        guard let client else { return }
        guard let platform = platforms.first(where: { $0.id == game.platformId }),
              let system = RomMGameImport.system(for: platform) else { throw RomMError.invalidContent }
        try await RomMGameImport.queue(game, from: client, system: system, staging: NearbyLibrariesModel.incomingStaging)
        imported.insert(game.id)
    }

}
#endif
