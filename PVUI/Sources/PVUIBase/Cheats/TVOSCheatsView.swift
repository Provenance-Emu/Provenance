//
//  TVOSCheatsView.swift
//  PVUI
//
//  Created for tvOS cheat codes support
//

#if os(tvOS)
import SwiftUI
import PVLibrary
import PVRealm
import RealmSwift
import PVThemes
import PVLogging

/// SwiftUI-based Cheats View for tvOS
/// This replaces the storyboard-based PVCheatsViewController on tvOS
public struct TVOSCheatsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared

    let cheats: LinkingObjects<PVCheats>
    let coreID: String?
    let cheatTypes: [String]
    let gameMD5: String?
    let gameTitle: String?
    let onSaveCheat: (String, String, String, UInt8, Bool) -> Void
    let onUpdateCheat: (PVCheats, UInt8) -> Void
    let onDone: () -> Void

    @State private var allCheats: [PVCheats] = []
    @State private var showingAddCheat = false
    @State private var showingSearchDB = false
    @State private var showingDeleteAlert = false
    @State private var cheatToDelete: PVCheats?
    @FocusState private var focusedCheatId: String?

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor
    }

    private var backgroundColor: Color {
        Color(themeManager.currentPalette.gameLibraryBackground)
    }

    public init(
        cheats: LinkingObjects<PVCheats>,
        coreID: String?,
        cheatTypes: [String],
        gameMD5: String? = nil,
        gameTitle: String? = nil,
        onSaveCheat: @escaping (String, String, String, UInt8, Bool) -> Void,
        onUpdateCheat: @escaping (PVCheats, UInt8) -> Void,
        onDone: @escaping () -> Void
    ) {
        self.cheats = cheats
        self.coreID = coreID
        self.cheatTypes = cheatTypes
        self.gameMD5 = gameMD5
        self.gameTitle = gameTitle
        self.onSaveCheat = onSaveCheat
        self.onUpdateCheat = onUpdateCheat
        self.onDone = onDone
    }

    public var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundColor.ignoresSafeArea()

                // Grid pattern
                RetroGrid(
                    lineSpacing: 30,
                    lineColor: accentColor.opacity(0.1)
                )
                .opacity(0.3)

                VStack(spacing: 0) {
                    // Header
                    headerView

                    if allCheats.isEmpty {
                        emptyStateView
                    } else {
                        cheatsListView
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadCheats()
        }
        .sheet(isPresented: $showingAddCheat) {
            TVOSAddCheatView(
                cheatTypes: cheatTypes,
                cheatIndex: UInt8(min(allCheats.count, Int(UInt8.max))),
                onSave: { code, type, codeType, index, enabled in
                    onSaveCheat(code, type, codeType, index, enabled)
                    loadCheats()
                }
            )
        }
        .sheet(isPresented: $showingSearchDB) {
            TVOSCheatSearchView(
                gameMD5: gameMD5,
                gameTitle: gameTitle,
                cheatTypes: cheatTypes,
                cheatIndex: UInt8(min(allCheats.count, Int(UInt8.max))),
                onImport: { code, name, deviceName, index, enabled in
                    onSaveCheat(code, name, deviceName, index, enabled)
                    loadCheats()
                }
            )
        }
        .alert("Delete Cheat Code?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let cheat = cheatToDelete {
                    deleteCheat(cheat)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Views

    private var headerView: some View {
        HStack {
            Button(action: {
                onDone()
                dismiss()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .bold))
                    Text("DONE")
                        .font(.system(size: 24, weight: .bold))
                }
                .foregroundColor(accentColor)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(accentColor, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("CHEAT CODES")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.currentPalette.gameLibraryHeaderText.swiftUIColor)
                .shadow(color: accentColor.opacity(0.8), radius: 10)

            Spacer()

            HStack(spacing: 16) {
                Button(action: {
                    showingSearchDB = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24, weight: .bold))
                        Text("SEARCH")
                            .font(.system(size: 24, weight: .bold))
                    }
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(accentColor, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)

                Button(action: {
                    showingAddCheat = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                        Text("ADD")
                            .font(.system(size: 24, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 40)
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 80))
                .foregroundColor(accentColor.opacity(0.5))

            Text("NO CHEAT CODES")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.7))

            Text("Add a cheat code to get started")
                .font(.system(size: 24))
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cheatsListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(allCheats.enumerated()), id: \.element.id) { index, cheat in
                    CheatRowView(
                        cheat: cheat,
                        index: UInt8(min(index, Int(UInt8.max))),
                        accentColor: accentColor,
                        onToggle: { toggleCheat(cheat, at: index) },
                        onDelete: {
                            cheatToDelete = cheat
                            showingDeleteAlert = true
                        }
                    )
                    .focused($focusedCheatId, equals: cheat.id)
                }
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Actions

    private func loadCheats() {
        if let coreID = coreID {
            let filter = "core.identifier == \"\(coreID)\""
            allCheats = cheats.filter(filter).sorted(byKeyPath: "date", ascending: true).map { $0 }
        } else {
            allCheats = cheats.sorted(byKeyPath: "date", ascending: true).map { $0 }
        }
    }

    private func toggleCheat(_ cheat: PVCheats, at index: Int) {
        do {
            let realm = try Realm()
            try realm.write {
                cheat.enabled.toggle()
            }
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

// MARK: - Cheat Row View

struct CheatRowView: View {
    let cheat: PVCheats
    let index: UInt8
    let accentColor: Color
    let onToggle: () -> Void
    let onDelete: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @FocusState private var isFocused: Bool

    private var cheatType: String {
        var type = cheat.type ?? ""
        if type.contains("-~-") {
            type = type.components(separatedBy: "-~-").first ?? type
        }
        return type
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 24) {
                // Status indicator
                Circle()
                    .fill(cheat.enabled ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(cheat.enabled ? Color.green.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 4)
                    )
                    .shadow(color: cheat.enabled ? .green.opacity(0.8) : .clear, radius: 8)

                // Cheat info
                VStack(alignment: .leading, spacing: 8) {
                    Text(cheatType)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)

                    Text(cheat.code ?? "")
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer()

                // Status text
                Text(cheat.enabled ? "ENABLED" : "DISABLED")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(cheat.enabled ? .green : .gray)

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 24))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(12)
                        .background(
                            Circle()
                                .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isFocused ? accentColor : (cheat.enabled ? Color.green.opacity(0.5) : Color.gray.opacity(0.3)),
                                lineWidth: isFocused ? 3 : 1.5
                            )
                    )
            )
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .shadow(color: isFocused ? accentColor.opacity(0.5) : .clear, radius: 15)
            .animation(.easeOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
    }
}

// MARK: - Add Cheat View

struct TVOSAddCheatView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared

    let cheatTypes: [String]
    let cheatIndex: UInt8
    let onSave: (String, String, String, UInt8, Bool) -> Void

    @State private var cheatName = ""
    @State private var cheatCode = ""
    @State private var selectedCodeType = 0
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, code
    }

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor
    }

    private var backgroundColor: Color {
        Color(themeManager.currentPalette.gameLibraryBackground)
    }

    private var selectedCodeTypeString: String {
        cheatTypes.isEmpty ? "" : cheatTypes[selectedCodeType]
    }

    private var validationResult: CheatCodeValidator.ValidationResult {
        CheatCodeValidator.validate(cheatCode, for: selectedCodeTypeString)
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            RetroGrid(
                lineSpacing: 30,
                lineColor: accentColor.opacity(0.1)
            )
            .opacity(0.3)

            VStack(spacing: 40) {
                // Header
                Text("ADD CHEAT CODE")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.currentPalette.gameLibraryHeaderText.swiftUIColor)
                    .shadow(color: accentColor.opacity(0.8), radius: 10)
                    .padding(.top, 40)

                // Form
                VStack(spacing: 32) {
                    // Name field
                    VStack(alignment: .leading, spacing: 12) {
                        Text("NAME")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(accentColor)

                        TextField("e.g. Infinite Lives", text: $cheatName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.5))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(focusedField == .name ? accentColor : accentColor.opacity(0.3), lineWidth: 2)
                                    )
                            )
                            .focused($focusedField, equals: .name)
                    }

                    // Code field
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CHEAT CODE")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(accentColor)

                        HStack(alignment: .center, spacing: 16) {
                            TextField(CheatCodeValidator.placeholder(for: selectedCodeTypeString), text: $cheatCode)
                                .textFieldStyle(.plain)
                                .font(.system(size: 28, design: .monospaced))
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.black.opacity(0.5))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(focusedField == .code ? accentColor : accentColor.opacity(0.3), lineWidth: 2)
                                        )
                                )
                                .focused($focusedField, equals: .code)
                                .onChangeCompat(of: cheatCode) {
                                    cheatCode = CheatCodeValidator.autoFormat(cheatCode, for: selectedCodeTypeString)
                                }

                            if !cheatCode.isEmpty {
                                Image(systemName: validationResult.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(validationResult.isValid ? .green : .red)
                                    .transition(.opacity)
                            }
                        }

                        if let hint = CheatCodeValidator.formatHint(for: selectedCodeTypeString) {
                            Text(hint)
                                .font(.system(size: 20))
                                .foregroundColor(accentColor.opacity(0.7))
                        }

                        if case .invalid(let errorHint) = validationResult, !cheatCode.isEmpty {
                            Text(errorHint)
                                .font(.system(size: 20))
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }

                    // Code type selector (hidden when only one type is supported)
                    if cheatTypes.count > 1 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CODE TYPE")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(accentColor)

                            HStack(spacing: 16) {
                                ForEach(Array(cheatTypes.enumerated()), id: \.offset) { index, type in
                                    Button(action: {
                                        selectedCodeType = index
                                    }) {
                                        Text(type)
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(selectedCodeType == index ? .white : .gray)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 16)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedCodeType == index ? accentColor : Color.black.opacity(0.5))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(accentColor.opacity(0.5), lineWidth: 1)
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 200)

                Spacer()

                // Buttons
                HStack(spacing: 40) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("CANCEL")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 60)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        saveCheat()
                    }) {
                        Text("SAVE")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 60)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(
                                        colors: [accentColor, accentColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(cheatCode.isEmpty)
                    .opacity(cheatCode.isEmpty ? 0.5 : 1.0)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            focusedField = .name
        }
    }

    private func saveCheat() {
        let name = cheatName.isEmpty ? "Cheat Code" : cheatName
        onSave(cheatCode, name, selectedCodeTypeString, cheatIndex, true)
        dismiss()
    }
}

// MARK: - Hosting Controller

public class TVOSCheatsHostingController: UIHostingController<TVOSCheatsView> {
    public init(
        cheats: LinkingObjects<PVCheats>,
        coreID: String?,
        cheatTypes: [String],
        gameMD5: String? = nil,
        gameTitle: String? = nil,
        onSaveCheat: @escaping (String, String, String, UInt8, Bool) -> Void,
        onUpdateCheat: @escaping (PVCheats, UInt8) -> Void,
        onDone: @escaping () -> Void
    ) {
        let view = TVOSCheatsView(
            cheats: cheats,
            coreID: coreID,
            cheatTypes: cheatTypes,
            gameMD5: gameMD5,
            gameTitle: gameTitle,
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

// MARK: - Cheat Database Search View (tvOS)

/// SwiftUI sheet shown when the user taps "SEARCH" in the cheat codes screen on tvOS.
struct TVOSCheatSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared

    let gameMD5: String?
    let gameTitle: String?
    /// Available cheat code types passed through from the parent view.
    /// Currently unused by the tvOS cheat database search UI, but kept to
    /// support future code-type selection/filtering when importing cheats
    /// and to maintain API consistency with other cheat views.
    let cheatTypes: [String]
    let cheatIndex: UInt8
    let onImport: (String, String, String, UInt8, Bool) -> Void

    @State private var results: [CheatDatabaseEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var filterText = ""
    @FocusState private var focusedID: Int?

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor
    }

    private var backgroundColor: Color {
        Color(themeManager.currentPalette.gameLibraryBackground)
    }

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
        ZStack {
            backgroundColor.ignoresSafeArea()
            RetroGrid(lineSpacing: 30, lineColor: accentColor.opacity(0.1))
                .opacity(0.3)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                            Text("CLOSE")
                        }
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(accentColor, lineWidth: 2))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("CHEAT DATABASE")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.currentPalette.gameLibraryHeaderText.swiftUIColor)
                        .shadow(color: accentColor.opacity(0.8), radius: 10)

                    Spacer()

                    // Filter field
                    TextField("Filter...", text: $filterText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .padding(12)
                        .frame(width: 300)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.5))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(accentColor.opacity(0.4), lineWidth: 2))
                        )
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 32)

                // Content
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(accentColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red.opacity(0.8))
                        .font(.system(size: 24))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(accentColor.opacity(0.4))
                        Text("No cheat codes found")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filtered) { entry in
                                TVOSCheatSearchRow(
                                    entry: entry,
                                    accentColor: accentColor,
                                    onImport: {
                                        onImport(entry.cheatCode, entry.cheatName, entry.deviceName, cheatIndex, true)
                                        dismiss()
                                    }
                                )
                                .focused($focusedID, equals: entry.id)
                            }
                        }
                        .padding(.horizontal, 80)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .task { await loadCheats() }
    }

    private func loadCheats() async {
        isLoading = true
        errorMessage = nil
        do {
            var found: [CheatDatabaseEntry] = []
            if let md5 = gameMD5, !md5.isEmpty {
                found = try await CheatDatabase.shared.searchCheats(byMD5: md5)
            }
            if found.isEmpty, let title = gameTitle, !title.isEmpty {
                found = try await CheatDatabase.shared.searchCheats(byTitle: title)
            }
            results = found
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct TVOSCheatSearchRow: View {
    let entry: CheatDatabaseEntry
    let accentColor: Color
    let onImport: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onImport) {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.cheatName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    Text(entry.cheatCode)
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .foregroundColor(accentColor)
                        .lineLimit(2)
                    Text("\(entry.deviceName)  ·  \(entry.category)")
                        .font(.system(size: 18))
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.55))
                }
                Spacer()
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 32))
                    .foregroundColor(accentColor)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isFocused ? accentColor : accentColor.opacity(0.3), lineWidth: isFocused ? 3 : 1.5)
                    )
            )
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .shadow(color: isFocused ? accentColor.opacity(0.5) : .clear, radius: 15)
            .animation(.easeOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
    }
}

#endif
