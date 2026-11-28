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
///
/// One list: the game's saved cheats, then every cheat the bundled database
/// and the online sources know for it. The lookups start when the view
/// appears; nothing is switched on until the user taps it.
public struct iOSCheatsView: View {
    @Environment(\.dismiss) private var dismiss

    let cheats: [PVCheats]
    let coreID: String?
    let cheatTypes: [String]
    let gameMD5: String?
    let gameTitle: String?
    let gameSystemIdentifier: String?
    let onSaveCheat: CheatSaveHandler
    let onUpdateCheat: (PVCheats, UInt8) -> Void
    let onDone: () -> Void

    @State private var loader: CheatCatalogLoader
    @State private var allCheats: [PVCheats] = []
    @State private var filterText = ""
    /// Codes being switched on: saved to the database but not yet reloaded.
    @State private var pendingKeys: Set<String> = []
    @State private var enableFailure: String?
    @State private var showingAddCheat = false
    @State private var cheatToEdit: CheatEditContext?
    @State private var cheatToExport: SharedCheatEntry?

    private struct CheatEditContext: Identifiable {
        let id: String
        let cheat: PVCheats
    }

    public init(
        cheats: [PVCheats],
        coreID: String?,
        cheatTypes: [String],
        gameMD5: String? = nil,
        gameTitle: String? = nil,
        gameSystemIdentifier: String? = nil,
        romSerial: String? = nil,
        onSaveCheat: @escaping CheatSaveHandler,
        onUpdateCheat: @escaping (PVCheats, UInt8) -> Void,
        onDone: @escaping () -> Void
    ) {
        self.cheats = cheats
        self.coreID = coreID
        self.cheatTypes = cheatTypes
        self.gameMD5 = gameMD5
        self.gameTitle = gameTitle
        self.gameSystemIdentifier = gameSystemIdentifier
        self.onSaveCheat = onSaveCheat
        self.onUpdateCheat = onUpdateCheat
        self.onDone = onDone
        _loader = State(initialValue: CheatCatalogLoader(query: CheatCatalogQuery(
            gameMD5: gameMD5,
            gameTitle: gameTitle,
            systemName: gameSystemIdentifier,
            romSerial: romSerial
        )))
    }

    private var nextCheatIndex: UInt8 {
        UInt8(min(allCheats.count, Int(UInt8.max)))
    }

    private var items: [CheatCatalogItem] {
        CheatCatalog.filter(
            CheatCatalog.merge(
                saved: allCheats.compactMap { SavedCheatSnapshot($0) },
                bundled: loader.bundled,
                online: loader.online
            ),
            matching: filterText
        )
    }

    public var body: some View {
        let items = self.items
        let savedItems = items.filter(\.isSaved)
        let offeredItems = items.filter { !$0.isSaved }
        NavigationStack {
            List {
                if !savedItems.isEmpty {
                    SwiftUI.Section("My Cheats") {
                        ForEach(savedItems) { item in
                            savedRow(item)
                        }
                    }
                }
                if !offeredItems.isEmpty {
                    SwiftUI.Section {
                        ForEach(offeredItems) { item in
                            iOSCheatRow(item: item, isPending: pendingKeys.contains(item.key))
                                .contentShape(Rectangle())
                                .onTapGesture { enable(item) }
                                .accessibilityAddTraits(.isButton)
                        }
                    } header: {
                        Text("Available for This Game")
                    } footer: {
                        Text("Tap a cheat to switch it on. Cheats marked with a globe come from the internet.")
                    }
                }
                SwiftUI.Section {
                    statusRow(isEmpty: items.isEmpty)
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $filterText, prompt: "Filter by name or code")
            .refreshable { await loader.refresh() }
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
                            Task { await loader.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(loader.isLoading)
                        .accessibilityLabel("Refresh Cheats")
                        Button {
                            showingAddCheat = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add Cheat Code")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    NavigationLink(destination: WikiPageView(path: "info/cheats.md", title: "Cheats Guide")) {
                        Label("Cheats Guide", systemImage: "questionmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddCheat) {
                iOSAddCheatView(
                    cheatTypes: cheatTypes,
                    cheatIndex: nextCheatIndex,
                    onSave: { code, name, codeType, index, enabled in
                        Task {
                            _ = await onSaveCheat(code, name, codeType, index, enabled)
                            loadCheats()
                        }
                    }
                )
            }
            .sheet(item: $cheatToEdit, onDismiss: { loadCheats() }) { ctx in
                iOSEditCheatView(cheat: ctx.cheat, cheatTypes: cheatTypes)
            }
            .sheet(item: $cheatToExport) { entry in
                CheatExportView(entry: entry)
            }
        }
        .pvAlert(item: $enableFailure) { name in
            PVAlert(
                title: "Cheat Not Switched On",
                message: "\"\(name)\" was not accepted by this core.",
                type: .error
            )
        }
        .onAppear { loadCheats() }
        .task { await loader.loadIfNeeded() }
    }

    // MARK: - Rows

    @ViewBuilder
    private func savedRow(_ item: CheatCatalogItem) -> some View {
        if let index = allCheats.firstIndex(where: { !$0.isInvalidated && $0.id == item.savedID }) {
            let cheat = allCheats[index]
            iOSCheatRow(item: item, isPending: false)
                .contentShape(Rectangle())
                .onTapGesture { toggleCheat(cheat, at: index) }
                .accessibilityAddTraits(.isButton)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteCheat(cheat)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        cheatToEdit = CheatEditContext(id: cheat.id, cheat: cheat)
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

    /// The last row: what the lookups are doing, or that they found nothing.
    @ViewBuilder
    private func statusRow(isEmpty: Bool) -> some View {
        if loader.isLoading {
            HStack(spacing: 12) {
                ProgressView()
                Text(verbatim: loader.isLoadingBundled ? "Looking up cheats…" : "Looking for more cheats online…")
                    .foregroundStyle(.secondary)
            }
        } else if loader.onlineState == .failed {
            HStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(.secondary)
                Text("Online cheats are unavailable right now.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Retry") {
                    Task { await loader.refresh() }
                }
                .buttonStyle(.borderless)
            }
        } else if isEmpty {
            Text(verbatim: filterText.isEmpty
                 ? "No cheats were found for this game. Tap + to add a code."
                 : "No cheats match \"\(filterText)\".")
                .foregroundStyle(.secondary)
        } else {
            Button {
                Task { await loader.refresh() }
            } label: {
                Label("Check for New Cheats", systemImage: "arrow.clockwise")
            }
        }
    }

    // MARK: - Helpers

    private func loadCheats() {
        // Re-query Realm when gameMD5 is available so newly added cheats
        // (written after this view was presented) are reflected on reload.
        let source: [PVCheats]
        if let md5 = gameMD5, !md5.isEmpty, let realm = try? Realm() {
            realm.refresh()
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

    /// Switches on a cheat from the database or an online source, which saves it.
    private func enable(_ item: CheatCatalogItem) {
        guard !pendingKeys.contains(item.key) else { return }
        pendingKeys.insert(item.key)
        let index = nextCheatIndex
        Task {
            let accepted = await onSaveCheat(item.code, item.name, item.codeType, index, true)
            loadCheats()
            pendingKeys.remove(item.key)
            if !accepted {
                enableFailure = item.name
            }
        }
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
    let item: CheatCatalogItem
    let isPending: Bool

    private var isOn: Bool { item.isEnabled || isPending }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isOn ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: item.name)
                        .font(.headline)
                        .lineLimit(1)
                    if item.source == .online {
                        Image(systemName: "globe")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .accessibilityLabel("From the internet")
                    }
                }
                Text(verbatim: item.code)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !item.isSaved, let detail = item.detail {
                    Text(verbatim: detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isPending {
                ProgressView()
            } else {
                Text(verbatim: isOn ? "ON" : "OFF")
                    .font(.caption.bold())
                    .foregroundStyle(isOn ? Color.green : Color.secondary)
            }
        }
        .padding(.vertical, 4)
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
        onSaveCheat: @escaping CheatSaveHandler,
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
