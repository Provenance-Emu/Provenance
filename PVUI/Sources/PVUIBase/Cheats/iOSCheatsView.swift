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

// MARK: - Main Cheats View

/// SwiftUI cheats management view for iOS.
public struct iOSCheatsView: View {
    @Environment(\.dismiss) private var dismiss

    let cheats: LinkingObjects<PVCheats>
    let coreID: String?
    let cheatTypes: [String]
    let gameMD5: String?
    let gameTitle: String?
    let gameSystemIdentifier: String?
    let onSaveCheat: (String, String, String, UInt8, Bool) -> Void
    let onUpdateCheat: (PVCheats, UInt8) -> Void
    let onDone: () -> Void

    @State private var allCheats: [PVCheats] = []
    @State private var showingAddCheat = false
    @State private var showingSearchDB = false
    @State private var cheatToEdit: CheatEditContext?

    private struct CheatEditContext: Identifiable {
        let id: String
        let cheat: PVCheats
        let index: Int
    }

    public init(
        cheats: LinkingObjects<PVCheats>,
        coreID: String?,
        cheatTypes: [String],
        gameMD5: String? = nil,
        gameTitle: String? = nil,
        gameSystemIdentifier: String? = nil,
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
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            "No Cheat Codes",
                            systemImage: "wand.and.stars",
                            description: Text("Add a code manually or search the database")
                        )
                    } else {
                        emptyStateView
                    }
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
                    cheatIndex: nextCheatIndex,
                    onImport: { code, name, deviceName, index, enabled in
                        onSaveCheat(code, name, deviceName, index, enabled)
                    }
                )
            }
            .sheet(item: $cheatToEdit, onDismiss: { delayedReload() }) { ctx in
                iOSEditCheatView(cheat: ctx.cheat, cheatTypes: cheatTypes)
            }
        }
        .onAppear { loadCheats() }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Cheat Codes")
                .font(.title2.bold())
            Text("Add a code manually or search the database")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    /// Reload the cheats list after a short delay to allow the async Realm write to complete.
    private func delayedReload() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            loadCheats()
        }
    }

    private func loadCheats() {
        if let coreID = coreID {
            let predicate = NSPredicate(format: "core.identifier == %@", coreID)
            allCheats = cheats.filter(predicate).sorted(byKeyPath: "date", ascending: true).map { $0 }
        } else {
            allCheats = cheats.sorted(byKeyPath: "date", ascending: true).map { $0 }
        }
    }

    private func toggleCheat(_ cheat: PVCheats, at index: Int) {
        do {
            let realm = try Realm()
            try realm.write { cheat.enabled.toggle() }
            onUpdateCheat(cheat, UInt8(min(index, Int(UInt8.max))))
            loadCheats()
        } catch {
            ELOG("Error toggling cheat: \(error)")
        }
    }

    private func deleteCheat(_ cheat: PVCheats) {
        do {
            try cheat.delete()
            loadCheats()
        } catch {
            ELOG("Error deleting cheat: \(error)")
        }
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

    let gameMD5: String?
    let gameTitle: String?
    let gameSystemIdentifier: String?
    let cheatIndex: UInt8
    let onImport: (String, String, String, UInt8, Bool) -> Void

    @State private var results: [CheatDatabaseEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var filterText = ""
    @State private var pendingEntry: CheatDatabaseEntry?
    @State private var showingConfirm = false

    private var filtered: [CheatDatabaseEntry] {
        guard !filterText.isEmpty else { return results }
        let lower = filterText.lowercased()
        return results.filter {
            $0.cheatName.lowercased().contains(lower) ||
            $0.category.lowercased().contains(lower) ||
            $0.deviceName.lowercased().contains(lower)
        }
    }

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
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView.search(text: filterText)
                    } else {
                        Text(filterText.isEmpty ? "No cheat codes found" : "No results for \"\(filterText)\"")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    List(filtered) { entry in
                        Button {
                            pendingEntry = entry
                            showingConfirm = true
                        } label: {
                            iOSCheatSearchRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
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
        .task { await loadCheats() }
    }

    private func loadCheats() async {
        isLoading = true
        errorMessage = nil
        DLOG("iOSCheatSearch: Starting search md5=\(gameMD5 ?? "nil") title=\(gameTitle ?? "nil") system=\(gameSystemIdentifier ?? "nil")")
        do {
            let found = try await CheatDatabase.shared.searchAllCheats(
                byMD5: gameMD5,
                title: gameTitle,
                systemIdentifier: gameSystemIdentifier
            )
            DLOG("iOSCheatSearch: \(found.count) results (unified search)")
            results = found
        } catch {
            ELOG("iOSCheatSearch error: \(error)")
            errorMessage = "\(error)"
        }
        isLoading = false
    }
}

// MARK: - Search Result Row

private struct iOSCheatSearchRow: View {
    let entry: CheatDatabaseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.cheatName)
                .font(.headline)
                .lineLimit(1)
            Text(entry.cheatCode)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text("\(entry.deviceName) · \(entry.category)")
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
        do {
            let realm = try Realm()
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
        cheats: LinkingObjects<PVCheats>,
        coreID: String?,
        cheatTypes: [String],
        gameMD5: String? = nil,
        gameTitle: String? = nil,
        gameSystemIdentifier: String? = nil,
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
