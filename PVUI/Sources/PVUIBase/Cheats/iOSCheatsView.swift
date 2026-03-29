// iOSCheatsView.swift
// PVUI
//
// SwiftUI-based cheats management view for iOS.
// Replaces the legacy storyboard-based PVCheatsViewController.

#if os(iOS)
import SwiftUI
import PVCoreBridge
import PVLibrary
import PVRealm
import RealmSwift
import PVThemes
import PVLogging
import PVFeatureFlags

// MARK: - Main Cheats View

/// SwiftUI cheats management view for iOS.
public struct iOSCheatsView: View {
    @Environment(\.dismiss) private var dismiss

    let cheats: [PVCheats]
    let coreID: String?
    let cheatTypes: [String]
    let gameMD5: String?
    let gameTitle: String?
    let gameSystemIdentifier: String?
    let romSerial: String?
    let onSaveCheat: (String, String, String, UInt8, Bool) -> Void
    let onUpdateCheat: (PVCheats, UInt8) -> Void
    let onDone: () -> Void

    @State private var allCheats: [PVCheats] = []
    @State private var showingAddCheat = false
    @State private var showingSearchDB = false
    @State private var cheatToEdit: CheatEditContext?
    @State private var cheatToExport: SharedCheatEntry?

    private struct CheatEditContext: Identifiable {
        let id: String
        let cheat: PVCheats
        let index: Int
    }

    public init(
        cheats: [PVCheats],
        coreID: String?,
        cheatTypes: [String],
        gameMD5: String? = nil,
        gameTitle: String? = nil,
        gameSystemIdentifier: String? = nil,
        romSerial: String? = nil,
        onSaveCheat: @escaping (String, String, String, UInt8, Bool) -> Void,
        onUpdateCheat: @escaping (PVCheats, UInt8) -> Void,
        onDone: @escaping () -> Void
    ) {
        self.cheats = cheats
        self.coreID = coreID
        self.cheatTypes = cheatTypes
        self.gameMD5 = gameMD5
        self.gameTitle = gameTitle
        self.gameSystemIdentifier = gameSystemIdentifier
        self.romSerial = romSerial
        self.onSaveCheat = onSaveCheat
        self.onUpdateCheat = onUpdateCheat
        self.onDone = onDone
    }

    private var nextCheatIndex: UInt8 {
        UInt8(min(allCheats.count, Int(UInt8.max)))
    }

    public var body: some View {
        NavigationStack {
            Group {
                if allCheats.isEmpty {
                    ContentUnavailableView(
                        "No Cheat Codes",
                        systemImage: "wand.and.stars",
                        description: Text("Add a code manually or search the database")
                    )
                } else {
                    List {
                        ForEach(Array(allCheats.enumerated()), id: \.element.id) { index, cheat in
                            iOSCheatRow(cheat: cheat)
                                .contentShape(Rectangle())
                                .onTapGesture { toggleCheat(cheat, at: index) }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteCheat(cheat)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        cheatToEdit = CheatEditContext(id: cheat.id, cheat: cheat, index: index)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                    Button {
                                        cheatToExport = sharedEntry(for: cheat)
                                    } label: {
                                        Label("Export", systemImage: "qrcode")
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Cheat Codes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDone()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        Button {
                            showingSearchDB = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        Button {
                            showingAddCheat = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    NavigationLink(destination: WikiPageView(path: "info/cheats.md", title: "Cheats Guide")) {
                        Label("Cheats Guide", systemImage: "questionmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddCheat, onDismiss: { delayedReload() }) {
                iOSAddCheatView(
                    cheatTypes: cheatTypes,
                    cheatIndex: nextCheatIndex,
                    onSave: { code, name, codeType, index, enabled in
                        onSaveCheat(code, name, codeType, index, enabled)
                    }
                )
            }
            .sheet(isPresented: $showingSearchDB, onDismiss: { delayedReload() }) {
                iOSCheatSearchView(
                    gameMD5: gameMD5,
                    gameTitle: gameTitle,
                    gameSystemIdentifier: gameSystemIdentifier,
                    romSerial: romSerial,
                    cheatIndex: nextCheatIndex,
                    onImport: { code, name, deviceName, index, enabled in
                        onSaveCheat(code, name, deviceName, index, enabled)
                    }
                )
            }
            .sheet(item: $cheatToEdit, onDismiss: { delayedReload() }) { ctx in
                iOSEditCheatView(cheat: ctx.cheat, cheatTypes: cheatTypes)
            }
            .sheet(item: $cheatToExport) { entry in
                CheatExportView(entry: entry)
            }
        }
        .onAppear {
            loadCheats()
            // Pre-warm the LibretroCheatDatabase so extraction happens now
            // (in background) rather than blocking when the user opens search.
            CheatDatabase.warmUpDatabases()
        }
    }

    // MARK: - Helpers

    /// Reload the cheats list after a short delay to allow the async Realm write to complete.
    private func delayedReload() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            loadCheats()
        }
    }

    private func loadCheats() {
        // Re-query Realm when gameMD5 is available so newly added/imported cheats
        // (written after this view was presented) are reflected on reload.
        let source: [PVCheats]
        if let md5 = gameMD5, !md5.isEmpty, let realm = try? Realm() {
            source = Array(realm.objects(PVCheats.self).filter("game.md5Hash == %@", md5))
        } else {
            source = cheats
        }
        let valid = source.filter { !$0.isInvalidated }
        let filtered: [PVCheats]
        if let coreID = coreID {
            filtered = valid.filter { $0.core?.identifier == coreID }
        } else {
            filtered = valid
        }
        allCheats = filtered.sorted { $0.date < $1.date }
    }

    private func toggleCheat(_ cheat: PVCheats, at index: Int) {
        guard !cheat.isInvalidated else {
            loadCheats(); return
        }
        // Use the realm that manages this object — opening a fresh Realm() risks
        // a different instance and causes a cross-Realm write crash.
        guard let realm = cheat.realm else {
            ELOG("toggleCheat: cheat has no associated realm")
            return
        }
        do {
            try realm.write { cheat.enabled.toggle() }
            onUpdateCheat(cheat, UInt8(min(index, Int(UInt8.max))))
            loadCheats()
        } catch {
            ELOG("Error toggling cheat: \(error)")
        }
    }

    private func deleteCheat(_ cheat: PVCheats) {
        guard !cheat.isInvalidated else {
            loadCheats(); return
        }
        do {
            try cheat.delete()
            loadCheats()
        } catch {
            ELOG("Error deleting cheat: \(error)")
        }
    }

    /// Converts a Realm-backed `PVCheats` into a `SharedCheatEntry` for export / QR sharing.
    private func sharedEntry(for cheat: PVCheats) -> SharedCheatEntry? {
        guard !cheat.isInvalidated, let code = cheat.code else { return nil }
        let name = cheat.type ?? code
        let format = cheat.codeType.isEmpty ? (cheat.type ?? "") : cheat.codeType
        let system = gameSystemIdentifier ?? cheat.game?.system?.name ?? cheat.game?.systemIdentifier ?? ""
        let game = cheat.game?.title ?? gameTitle ?? ""
        return SharedCheatEntry(
            id: UUID(uuidString: cheat.id) ?? UUID(),
            name: name,
            code: code,
            format: format,
            systemName: system,
            gameName: game,
            addedDate: cheat.date
        )
    }
}

// MARK: - Cheat Row

private struct iOSCheatRow: View {
    let cheat: PVCheats

    private var displayName: String {
        let type = cheat.type ?? ""
        return type.isEmpty ? "Cheat Code" : type
    }

    var body: some View {
        // Guard against Realm invalidation: if the object was deleted or the
        // Realm refreshed mid-render, any property access would crash.
        if !cheat.isInvalidated {
            HStack(spacing: 12) {
                Circle()
                    .fill(cheat.enabled ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(cheat.code ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(cheat.enabled ? "ON" : "OFF")
                    .font(.caption.bold())
                    .foregroundStyle(cheat.enabled ? Color.green : Color.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Add Cheat View

/// Form sheet for manually entering a cheat code.
/// Supports code type selection and basic format validation.
struct iOSAddCheatView: View {
    @Environment(\.dismiss) private var dismiss

    let cheatTypes: [String]
    let cheatIndex: UInt8
    let onSave: (String, String, String, UInt8, Bool) -> Void

    @State private var cheatName = ""
    @State private var cheatCode = ""
    @State private var selectedTypeIndex = 0
    @FocusState private var focusedField: Field?

    private enum Field { case name, code }

    private var selectedType: String {
        cheatTypes.isEmpty ? "" : cheatTypes[selectedTypeIndex]
    }

    /// Real-time validation result for the current code and selected type.
    private var validationResult: CheatCodeValidator.ValidationResult {
        CheatCodeValidator.validate(cheatCode, for: selectedType)
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                codeSection
                typeSection
            }
            .navigationTitle("Add Cheat Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCheat() }
                        .disabled(validationResult == .empty)
                }
            }
            .onAppear { focusedField = .name }
        }
    }

    @ViewBuilder
    private var nameSection: some View {
        SwiftUI.Section("Name") {
            TextField("e.g. Infinite Lives", text: $cheatName)
                .focused($focusedField, equals: .name)
        }
    }

    @ViewBuilder
    private var codeSection: some View {
        SwiftUI.Section {
            if CheatCodeValidator.supportsMultiLine(for: selectedType) {
                HStack(alignment: .top) {
                    TextEditor(text: $cheatCode)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($focusedField, equals: .code)
                        .frame(minHeight: 80)
                    if !cheatCode.isEmpty {
                        Image(systemName: validationResult.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(validationResult.isValid ? Color.green : Color.red)
                            .transition(.opacity)
                    }
                }
            } else {
                HStack {
                    TextField(CheatCodeValidator.placeholder(for: selectedType), text: $cheatCode)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($focusedField, equals: .code)
                        .onChangeCompat(of: cheatCode) {
                            cheatCode = CheatCodeValidator.autoFormat(cheatCode, for: selectedType)
                        }
                    if !cheatCode.isEmpty {
                        Image(systemName: validationResult.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(validationResult.isValid ? Color.green : Color.red)
                            .transition(.opacity)
                    }
                }
            }
        } header: {
            Text("Cheat Code")
        } footer: {
            if let error = validationResult.errorHint, !cheatCode.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.red)
            } else if let hint = CheatCodeValidator.formatHint(for: selectedType) {
                Text("Format: \(hint)")
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var typeSection: some View {
        if cheatTypes.count > 1 {
            SwiftUI.Section("Code Type") {
                Picker("Code Type", selection: $selectedTypeIndex) {
                    ForEach(0..<cheatTypes.count, id: \.self) { index in
                        Text(CheatCodeTypes(string: cheatTypes[index])?.stringValue ?? cheatTypes[index]).tag(index)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func saveCheat() {
        let trimmedName = cheatName.trimmingCharacters(in: .whitespaces)
        let name = trimmedName.isEmpty ? "Cheat Code" : trimmedName
        let code = cheatCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        onSave(code, name, selectedType, cheatIndex, true)
        dismiss()
    }
}

// MARK: - Cheat Database Search View (iOS)

/// Sheet for searching the bundled cheat database and importing entries.
struct iOSCheatSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.featureFlags) private var featureFlags

    let gameMD5: String?
    let gameTitle: String?
    let gameSystemIdentifier: String?
    let romSerial: String?
    let cheatIndex: UInt8
    let onImport: (String, String, String, UInt8, Bool) -> Void

    @State private var results: [CheatDatabaseEntry] = []
    @State private var isLoading = false
    @State private var isOnlineSearching = false
    @State private var errorMessage: String?
    @State private var onlineErrorMessage: String?
    @State private var filterText = ""
    @State private var pendingEntry: CheatDatabaseEntry?
    @State private var showingConfirm = false
    @State private var hasSearchedOnline = false

    private var onlineLookupEnabled: Bool { featureFlags.cheatsOnlineLookup }

    private var filtered: [CheatDatabaseEntry] {
        guard !filterText.isEmpty else { return results }
        let lower = filterText.lowercased()
        return results.filter {
            $0.cheatName.lowercased().contains(lower) ||
            $0.category.lowercased().contains(lower) ||
            $0.deviceName.lowercased().contains(lower)
        }
    }

    private var hasOnlineResults: Bool { results.contains { $0.isOnlineResult } }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading database…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.red)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("Cheat Database")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $filterText, prompt: "Filter by name or category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .alert(
            "Import Cheat?",
            isPresented: $showingConfirm,
            presenting: pendingEntry
        ) { entry in
            Button("Import") {
                onImport(entry.cheatCode, entry.cheatName, entry.deviceName, cheatIndex, true)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: { entry in
            Text("\"\(entry.cheatName)\"\n\(entry.cheatCode)")
        }
        .alert(
            "Online Search Failed",
            isPresented: Binding(get: { onlineErrorMessage != nil }, set: { if !$0 { onlineErrorMessage = nil } })
        ) {
            Button("OK", role: .cancel) { onlineErrorMessage = nil }
        } message: {
            Text(onlineErrorMessage ?? "")
        }
        .task { await loadCheats() }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            if !filterText.isEmpty {
                ContentUnavailableView.search(text: filterText)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No local cheat codes found")
                        .foregroundStyle(.secondary)
                }
            }

            if onlineLookupEnabled, !hasSearchedOnline, !isOnlineSearching, filterText.isEmpty {
                Button {
                    Task { await searchOnline() }
                } label: {
                    Label("Search Online", systemImage: "globe")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)

                Text("Fetches from libretro cheat database and GameHacking.org")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .center) {
            if isOnlineSearching {
                ProgressView("Searching online…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder
    private var listView: some View {
        SwiftUI.List {
            if hasOnlineResults {
                SwiftUI.Section {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .foregroundStyle(.blue)
                        Text("Some results are from the internet. Review before importing.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(filtered) { entry in
                Button {
                    pendingEntry = entry
                    showingConfirm = true
                } label: {
                    iOSCheatSearchRow(entry: entry)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .overlay(alignment: .bottom) {
            if isOnlineSearching {
                ProgressView("Searching online…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if onlineLookupEnabled, !hasSearchedOnline, !isOnlineSearching, !results.isEmpty, filterText.isEmpty,
               let sysID = gameSystemIdentifier, !sysID.isEmpty {
                Button {
                    Task { await searchOnline() }
                } label: {
                    Label("Also Search Online", systemImage: "globe")
                        .font(.subheadline)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding()
                .background(.regularMaterial)
            }
        }
    }

    // MARK: - Data Loading

    private func loadCheats() async {
        isLoading = true
        errorMessage = nil
        DLOG("iOSCheatSearch: Starting search md5=\(gameMD5 ?? "nil") title=\(gameTitle ?? "nil") system=\(gameSystemIdentifier ?? "nil") serial=\(romSerial ?? "nil")")
        do {
            let found = try await CheatDatabase.shared.searchAllCheats(
                byMD5: gameMD5,
                title: gameTitle,
                systemIdentifier: gameSystemIdentifier,
                romSerial: romSerial
            )
            DLOG("iOSCheatSearch: \(found.count) results (unified search)")
            results = found
        } catch {
            ELOG("iOSCheatSearch error: \(error)")
            errorMessage = "\(error)"
        }
        isLoading = false
    }

    private func searchOnline() async {
        guard let title = gameTitle, !title.isEmpty else { return }
        isOnlineSearching = true
        defer { isOnlineSearching = false }
        onlineErrorMessage = nil
        DLOG("iOSCheatSearch: online lookup for title='\(title)' system=\(gameSystemIdentifier ?? "nil")")
        do {
            let online = try await CheatDatabase.shared.searchCheatsOnline(
                title: title,
                systemIdentifier: gameSystemIdentifier
            )
            DLOG("iOSCheatSearch: \(online.count) online results")
            // Merge, deduplicating by cheat code
            var seen = Set(results.map { $0.cheatCode.lowercased() })
            for entry in online where seen.insert(entry.cheatCode.lowercased()).inserted {
                results.append(entry)
            }
            hasSearchedOnline = true
        } catch {
            ELOG("iOSCheatSearch online error: \(error)")
            onlineErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Search Result Row

private struct iOSCheatSearchRow: View {
    let entry: CheatDatabaseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(entry.cheatName)
                    .font(.headline)
                    .lineLimit(1)
                if entry.isOnlineResult {
                    Image(systemName: "globe")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .help("From online database")
                }
            }
            Text(entry.cheatCode)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text("\(entry.deviceFormat ?? entry.deviceName) · \(entry.category)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit Cheat View

/// Form sheet for editing an existing cheat code's name, code, and type.
/// Pre-populated from the saved `PVCheats` values and writes changes to Realm on save.
struct iOSEditCheatView: View {
    @Environment(\.dismiss) private var dismiss

    let cheat: PVCheats
    let cheatTypes: [String]

    @State private var cheatName: String
    @State private var cheatCode: String
    @State private var selectedTypeIndex: Int
    @FocusState private var focusedField: Field?

    private enum Field { case name, code }

    init(cheat: PVCheats, cheatTypes: [String]) {
        self.cheat = cheat
        self.cheatTypes = cheatTypes
        let rawType = cheat.type ?? ""
        let cheatName = rawType.isEmpty ? "Cheat Code" : rawType
        _cheatName = State(initialValue: cheatName)
        _cheatCode = State(initialValue: cheat.code ?? "")
        _selectedTypeIndex = State(initialValue: cheatTypes.firstIndex(of: cheat.codeType) ?? 0)
    }

    private var selectedType: String {
        cheatTypes.isEmpty ? "" : cheatTypes[selectedTypeIndex]
    }

    private var validationResult: CheatCodeValidator.ValidationResult {
        CheatCodeValidator.validate(cheatCode, for: selectedType)
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Name") {
                    TextField("e.g. Infinite Lives", text: $cheatName)
                        .focused($focusedField, equals: .name)
                }

                SwiftUI.Section {
                    if CheatCodeValidator.supportsMultiLine(for: selectedType) {
                        HStack(alignment: .top) {
                            TextEditor(text: $cheatCode)
                                .font(.system(.body, design: .monospaced))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                                .focused($focusedField, equals: .code)
                                .frame(minHeight: 80)
                            if !cheatCode.isEmpty {
                                Image(systemName: validationResult.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(validationResult.isValid ? Color.green : Color.red)
                            }
                        }
                    } else {
                        HStack {
                            TextField(CheatCodeValidator.placeholder(for: selectedType), text: $cheatCode)
                                .font(.system(.body, design: .monospaced))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                                .focused($focusedField, equals: .code)
                                .onChangeCompat(of: cheatCode) {
                                    cheatCode = CheatCodeValidator.autoFormat(cheatCode, for: selectedType)
                                }
                            if !cheatCode.isEmpty {
                                Image(systemName: validationResult.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(validationResult.isValid ? Color.green : Color.red)
                            }
                        }
                    }
                } header: {
                    Text("Cheat Code")
                } footer: {
                    if let error = validationResult.errorHint, !cheatCode.isEmpty {
                        Text(error).font(.caption).foregroundStyle(Color.red)
                    } else if let hint = CheatCodeValidator.formatHint(for: selectedType) {
                        Text("Format: \(hint)").font(.caption)
                    }
                }

                if cheatTypes.count > 1 {
                    SwiftUI.Section("Code Type") {
                        Picker("Code Type", selection: $selectedTypeIndex) {
                            ForEach(0..<cheatTypes.count, id: \.self) { index in
                                Text(CheatCodeTypes(string: cheatTypes[index])?.stringValue ?? cheatTypes[index]).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle("Edit Cheat Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCheat() }
                        .disabled(validationResult == .empty)
                }
            }
        }
    }

    private func saveCheat() {
        let trimmedName = cheatName.trimmingCharacters(in: .whitespaces)
        let name = trimmedName.isEmpty ? "Cheat Code" : trimmedName
        let code = cheatCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        guard !cheat.isInvalidated, let realm = cheat.realm else {
            ELOG("saveCheat: cheat is invalidated or detached from Realm")
            dismiss()
            return
        }
        do {
            try realm.write {
                cheat.code = code
                cheat.type = name
                cheat.codeType = selectedType
            }
            dismiss()
        } catch {
            ELOG("Error saving edited cheat: \(error)")
        }
    }
}

// MARK: - Hosting Controller

/// `UIHostingController` bridge so the SwiftUI cheats view can be presented
/// from UIKit code in `PVEmulatorViewController`.
public class iOSCheatsHostingController: UIHostingController<iOSCheatsView> {
    public init(
        cheats: [PVCheats],
        coreID: String?,
        cheatTypes: [String],
        gameMD5: String? = nil,
        gameTitle: String? = nil,
        gameSystemIdentifier: String? = nil,
        romSerial: String? = nil,
        onSaveCheat: @escaping (String, String, String, UInt8, Bool) -> Void,
        onUpdateCheat: @escaping (PVCheats, UInt8) -> Void,
        onDone: @escaping () -> Void
    ) {
        let view = iOSCheatsView(
            cheats: cheats,
            coreID: coreID,
            cheatTypes: cheatTypes,
            gameMD5: gameMD5,
            gameTitle: gameTitle,
            gameSystemIdentifier: gameSystemIdentifier,
            romSerial: romSerial,
            onSaveCheat: onSaveCheat,
            onUpdateCheat: onUpdateCheat,
            onDone: onDone
        )
        super.init(rootView: view)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


#endif
