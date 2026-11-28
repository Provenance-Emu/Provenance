//
//  TVOSCheatsView.swift
//  PVUI
//
//  Created for tvOS cheat codes support
//

#if os(tvOS)
import SwiftUI
import UIKit
import PVCoreBridge
import PVLibrary
import PVRealm
import RealmSwift
import PVThemes
import PVLogging
import PVFeatureFlags

/// UIKit-backed multiline editor used in tvOS cheat forms where `TextEditor`
/// is unavailable.
private struct TVOSMultilineCodeEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = TVOSFocusableTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.font = .monospacedSystemFont(ofSize: 24, weight: .regular)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .allCharacters
        textView.spellCheckingType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.keyboardAppearance = .dark
        textView.returnKeyType = .default
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        textView.text = text
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        if isFocused, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    /// Bridges `UITextViewDelegate` events back into SwiftUI state.
    final class Coordinator: NSObject, UITextViewDelegate {
        private let text: Binding<String>
        private let isFocused: Binding<Bool>

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            self.text = text
            self.isFocused = isFocused
        }

        func textViewDidChange(_ textView: UITextView) {
            let updatedText = textView.text ?? ""
            if text.wrappedValue != updatedText {
                text.wrappedValue = updatedText
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if !isFocused.wrappedValue {
                isFocused.wrappedValue = true
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if isFocused.wrappedValue {
                isFocused.wrappedValue = false
            }
        }
    }
}

/// Focusable `UITextView` subclass so cheat code editing can participate in the
/// tvOS focus system.
private final class TVOSFocusableTextView: UITextView {
    override var canBecomeFocused: Bool {
        true
    }
}

/// SwiftUI-based Cheats View for tvOS
///
/// One list: the game's saved cheats, then every cheat the bundled database
/// and the online sources know for it. The lookups start when the view
/// appears; nothing is switched on until the user selects it.
public struct TVOSCheatsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared

    let cheats: [PVCheats]
    let coreID: String?
    let cheatTypes: [String]
    let gameMD5: String?
    let onSaveCheat: CheatSaveHandler
    let onUpdateCheat: (PVCheats, UInt8) -> Void
    let onDone: () -> Void

    /// Rows before the filter field is worth the space it takes.
    private static let filterThreshold = 12

    @State private var loader: CheatCatalogLoader
    @State private var allCheats: [PVCheats] = []
    @State private var filterText = ""
    /// Codes being switched on: saved to the database but not yet reloaded.
    @State private var pendingKeys: Set<String> = []
    @State private var enableFailure: String?
    @State private var showingAddCheat = false
    @State private var showingDeleteAlert = false
    @State private var cheatToDelete: PVCheats?
    @State private var cheatToEdit: CheatEditContext?
    @FocusState private var focusedItemID: String?

    private struct CheatEditContext: Identifiable {
        let id: String
        let cheat: PVCheats
    }

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor
    }

    private var backgroundColor: Color {
        Color(themeManager.currentPalette.gameLibraryBackground)
    }

    private var textColor: Color {
        themeManager.currentPalette.gameLibraryText.swiftUIColor
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

    private var allItems: [CheatCatalogItem] {
        CheatCatalog.merge(
            saved: allCheats.compactMap { SavedCheatSnapshot($0) },
            bundled: loader.bundled,
            online: loader.online
        )
    }

    public var body: some View {
        let allItems = self.allItems
        let items = CheatCatalog.filter(allItems, matching: filterText)
        NavigationStack {
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

                    if allItems.isEmpty, !loader.isLoading {
                        emptyStateView
                    } else {
                        cheatsListView(items: items, showsFilter: allItems.count > Self.filterThreshold)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            loadCheats()
        }
        .task { await loader.loadIfNeeded() }
        .sheet(isPresented: $showingAddCheat) {
            TVOSAddCheatView(
                cheatTypes: cheatTypes,
                cheatIndex: nextCheatIndex,
                onSave: { code, type, codeType, index, enabled in
                    Task {
                        _ = await onSaveCheat(code, type, codeType, index, enabled)
                        loadCheats()
                    }
                }
            )
        }
        .sheet(item: $cheatToEdit, onDismiss: { loadCheats() }) { ctx in
            TVOSEditCheatView(cheat: ctx.cheat, cheatTypes: cheatTypes)
        }
        .pvAlert(isPresented: $showingDeleteAlert) {
            let cheat = cheatToDelete
            return PVAlert(
                title: "Delete Cheat Code?",
                message: "This action cannot be undone.",
                type: .warning,
                actions: [
                    PVAlertAction("Delete", role: .destructive) {
                        guard let cheat else { return }
                        deleteCheat(cheat)
                    },
                    .cancel()
                ]
            )
        }
        .pvAlert(item: $enableFailure) { name in
            PVAlert(
                title: "Cheat Not Switched On",
                message: "\"\(name)\" was not accepted by this core.",
                type: .error
            )
        }
    }

    // MARK: - Views

    /// An outlined header button's label.
    private func headerLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .bold))
            Text(verbatim: title)
                .font(.system(size: 24, weight: .bold))
        }
        .foregroundStyle(accentColor)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor, lineWidth: 2)
        )
    }

    private var headerView: some View {
        HStack {
            Button(action: {
                onDone()
                dismiss()
            }) {
                headerLabel("DONE", systemImage: "xmark")
            }
            .buttonStyle(.plain)

            Spacer()

            Text("CHEAT CODES")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.currentPalette.gameLibraryHeaderText.swiftUIColor)
                .shadow(color: accentColor.opacity(0.8), radius: 10)

            Spacer()

            HStack(spacing: 16) {
                NavigationLink(destination: WikiPageView(path: "info/cheats.md", title: "Cheats Guide")) {
                    headerLabel("HELP", systemImage: "questionmark.circle")
                }
                .buttonStyle(.plain)

                Button(action: {
                    Task { await loader.refresh() }
                }) {
                    headerLabel("REFRESH", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(loader.isLoading)
                .opacity(loader.isLoading ? 0.5 : 1.0)

                Button(action: {
                    showingAddCheat = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                        Text("ADD")
                            .font(.system(size: 24, weight: .bold))
                    }
                    .foregroundStyle(.white)
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
                .foregroundStyle(accentColor.opacity(0.5))

            Text("NO CHEAT CODES")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(textColor.opacity(0.7))

            Text(verbatim: loader.onlineState == .failed
                 ? "Online cheats are unavailable right now. Add a code, or try again later."
                 : "No cheats were found for this game. Add a code to get started.")
                .font(.system(size: 24))
                .foregroundStyle(textColor.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(verbatim: title)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(accentColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    private func cheatsListView(items: [CheatCatalogItem], showsFilter: Bool) -> some View {
        let savedItems = items.filter(\.isSaved)
        let offeredItems = items.filter { !$0.isSaved }
        return ScrollView {
            LazyVStack(spacing: 16) {
                if showsFilter {
                    TextField("Filter by name or code", text: $filterText)
                        .font(.system(size: 24))
                }

                if !savedItems.isEmpty {
                    sectionHeader("MY CHEATS")
                    ForEach(savedItems) { item in
                        savedRow(item)
                    }
                }

                if !offeredItems.isEmpty {
                    sectionHeader("AVAILABLE FOR THIS GAME")
                    ForEach(offeredItems) { item in
                        TVOSOfferedCheatRow(
                            item: item,
                            isPending: pendingKeys.contains(item.key),
                            accentColor: accentColor,
                            onEnable: { enable(item, among: offeredItems) }
                        )
                        .focused($focusedItemID, equals: item.id)
                    }
                }

                statusRow(isEmpty: items.isEmpty)
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 24)
        }
    }

}

// MARK: - Rows and Actions

extension TVOSCheatsView {
    @ViewBuilder
    private func savedRow(_ item: CheatCatalogItem) -> some View {
        if let index = allCheats.firstIndex(where: { !$0.isInvalidated && $0.id == item.savedID }) {
            let cheat = allCheats[index]
            CheatRowView(
                cheat: cheat,
                index: UInt8(min(index, Int(UInt8.max))),
                accentColor: accentColor,
                onToggle: { toggleCheat(cheat, at: index) },
                onEdit: {
                    cheatToEdit = CheatEditContext(id: cheat.id, cheat: cheat)
                },
                onDelete: {
                    cheatToDelete = cheat
                    showingDeleteAlert = true
                }
            )
            .focused($focusedItemID, equals: item.id)
        }
    }

    /// The last row: what the lookups are doing, or that they found nothing.
    @ViewBuilder
    private func statusRow(isEmpty: Bool) -> some View {
        if loader.isLoading {
            HStack(spacing: 16) {
                ProgressView()
                    .tint(accentColor)
                Text(verbatim: loader.isLoadingBundled ? "Looking up cheats…" : "Looking for more cheats online…")
                    .font(.system(size: 22))
                    .foregroundStyle(textColor.opacity(0.6))
            }
            .padding(.vertical, 16)
        } else if loader.onlineState == .failed {
            HStack(spacing: 24) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 24))
                    .foregroundStyle(textColor.opacity(0.6))
                Text("Online cheats are unavailable right now.")
                    .font(.system(size: 22))
                    .foregroundStyle(textColor.opacity(0.6))
                Button(action: {
                    Task { await loader.refresh() }
                }) {
                    headerLabel("RETRY", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 16)
        } else if isEmpty {
            Text("No cheats match \"\(filterText)\".")
                .font(.system(size: 22))
                .foregroundStyle(textColor.opacity(0.6))
                .padding(.vertical, 16)
        }
    }

    // MARK: - Actions

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
    ///
    /// The row then moves up to the saved cheats. Focus goes to the row that
    /// takes its place, so that several cheats can be switched on in a row
    /// without the list jumping to the top.
    private func enable(_ item: CheatCatalogItem, among offeredItems: [CheatCatalogItem]) {
        guard !pendingKeys.contains(item.key) else { return }
        pendingKeys.insert(item.key)
        let index = nextCheatIndex
        var neighbourID: String?
        if let position = offeredItems.firstIndex(of: item) {
            if position + 1 < offeredItems.count {
                neighbourID = offeredItems[position + 1].id
            } else if position > 0 {
                neighbourID = offeredItems[position - 1].id
            }
        }
        Task {
            let accepted = await onSaveCheat(item.code, item.name, item.codeType, index, true)
            if accepted, focusedItemID == item.id, let neighbourID {
                focusedItemID = neighbourID
            }
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
}

// MARK: - Offered Cheat Row

/// A cheat from the database or an online source that is not switched on yet.
private struct TVOSOfferedCheatRow: View {
    let item: CheatCatalogItem
    let isPending: Bool
    let accentColor: Color
    let onEnable: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @FocusState private var isFocused: Bool

    private var textColor: Color {
        themeManager.currentPalette.gameLibraryText.swiftUIColor
    }

    var body: some View {
        Button(action: onEnable) {
            HStack(spacing: 24) {
                Circle()
                    .fill(isPending ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(verbatim: item.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                        if item.source == .online {
                            Image(systemName: "globe")
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)
                                .accessibilityLabel("From the internet")
                        }
                    }
                    Text(verbatim: item.code)
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundStyle(textColor.opacity(0.7))
                        .lineLimit(1)
                    if let detail = item.detail {
                        Text(verbatim: detail)
                            .font(.system(size: 18))
                            .foregroundStyle(textColor.opacity(0.55))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isPending {
                    ProgressView()
                        .tint(accentColor)
                } else {
                    Text("DISABLED")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isFocused ? accentColor : Color.gray.opacity(0.3), lineWidth: isFocused ? 3 : 1.5)
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

// MARK: - Cheat Row View

struct CheatRowView: View {
    let cheat: PVCheats
    let index: UInt8
    let accentColor: Color
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @FocusState private var isFocused: Bool

    private var cheatType: String {
        cheat.isInvalidated ? "" : (cheat.type ?? "")
    }

    var body: some View {
        guard !cheat.isInvalidated else { return AnyView(EmptyView()) }
        return AnyView(Button(action: onToggle) {
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
                        .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor)

                    Text(cheat.code ?? "")
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer()

                // Status text
                Text(cheat.enabled ? "ENABLED" : "DISABLED")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(cheat.enabled ? .green : .gray)

                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 24))
                        .foregroundStyle(accentColor.opacity(0.8))
                        .padding(12)
                        .background(
                            Circle()
                                .stroke(accentColor.opacity(0.5), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 24))
                        .foregroundStyle(.red.opacity(0.8))
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
    ) // AnyView
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
                    .foregroundStyle(themeManager.currentPalette.gameLibraryHeaderText.swiftUIColor)
                    .shadow(color: accentColor.opacity(0.8), radius: 10)
                    .padding(.top, 40)

                // Form
                VStack(spacing: 32) {
                    // Name field
                    VStack(alignment: .leading, spacing: 12) {
                        Text("NAME")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(accentColor)

                        TextField("e.g. Infinite Lives", text: $cheatName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
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
                            .foregroundStyle(accentColor)

                        HStack(alignment: .center, spacing: 16) {
                            if CheatCodeValidator.supportsMultiLine(for: selectedCodeTypeString) {
                                TVOSMultilineCodeEditor(
                                    text: $cheatCode,
                                    isFocused: Binding(
                                        get: { focusedField == .code },
                                        set: { focusedField = $0 ? .code : nil }
                                    )
                                )
                                    .frame(minHeight: 100)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.black.opacity(0.5))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(focusedField == .code ? accentColor : accentColor.opacity(0.3), lineWidth: 2)
                                            )
                                    )
                            } else {
                                TextField(CheatCodeValidator.placeholder(for: selectedCodeTypeString), text: $cheatCode)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 28, design: .monospaced))
                                    .foregroundStyle(.white)
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
                            }

                            if !cheatCode.isEmpty {
                                Image(systemName: validationResult.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(validationResult.isValid ? .green : .red)
                                    .transition(.opacity)
                            }
                        }

                        if let hint = CheatCodeValidator.formatHint(for: selectedCodeTypeString) {
                            Text(hint)
                                .font(.system(size: 20))
                                .foregroundStyle(accentColor.opacity(0.7))
                        }

                        if case .invalid(let errorHint) = validationResult, !cheatCode.isEmpty {
                            Text(errorHint)
                                .font(.system(size: 20))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }

                    // Code type selector (hidden when only one type is supported)
                    if cheatTypes.count > 1 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CODE TYPE")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(accentColor)

                            HStack(spacing: 16) {
                                ForEach(Array(cheatTypes.enumerated()), id: \.offset) { index, codeType in
                                    Button(action: {
                                        selectedCodeType = index
                                    }) {
                                        Text(CheatCodeTypes(string: codeType)?.stringValue ?? codeType)
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundStyle(selectedCodeType == index ? .white : .gray)
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
                            .foregroundStyle(.gray)
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
                            .foregroundStyle(.white)
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
                    .disabled(validationResult == .empty)
                    .opacity(validationResult == .empty ? 0.5 : 1.0)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            focusedField = .name
        }
    }

    private func saveCheat() {
        let code = cheatCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        let trimmedName = cheatName.trimmingCharacters(in: .whitespaces)
        let name = trimmedName.isEmpty ? "Cheat Code" : trimmedName
        onSave(code, name, selectedCodeTypeString, cheatIndex, true)
        dismiss()
    }
}

// MARK: - Edit Cheat View (tvOS)

/// Full-screen form for editing an existing cheat code on tvOS.
/// Pre-populated with the saved values; writes updates to Realm on save.
struct TVOSEditCheatView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared

    let cheat: PVCheats
    let cheatTypes: [String]

    @State private var cheatName: String
    @State private var cheatCode: String
    @State private var selectedCodeType: Int
    @FocusState private var focusedField: Field?

    private enum Field { case name, code }

    private var accentColor: Color { themeManager.currentPalette.defaultTintColor.swiftUIColor }
    private var backgroundColor: Color { Color(themeManager.currentPalette.gameLibraryBackground) }

    init(cheat: PVCheats, cheatTypes: [String]) {
        self.cheat = cheat
        self.cheatTypes = cheatTypes
        let rawType = cheat.type ?? ""
        let cheatName = rawType.isEmpty ? "Cheat Code" : rawType
        _cheatName = State(initialValue: cheatName)
        _cheatCode = State(initialValue: cheat.code ?? "")
        _selectedCodeType = State(initialValue: cheatTypes.firstIndex(of: cheat.codeType) ?? 0)
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
            RetroGrid(lineSpacing: 30, lineColor: accentColor.opacity(0.1)).opacity(0.3)

            VStack(spacing: 40) {
                Text("EDIT CHEAT CODE")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.currentPalette.gameLibraryHeaderText.swiftUIColor)
                    .shadow(color: accentColor.opacity(0.8), radius: 10)
                    .padding(.top, 40)

                VStack(spacing: 32) {
                    // Name field
                    VStack(alignment: .leading, spacing: 12) {
                        Text("NAME")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(accentColor)
                        TextField("e.g. Infinite Lives", text: $cheatName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
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
                            .foregroundStyle(accentColor)

                        HStack(alignment: .center, spacing: 16) {
                            if CheatCodeValidator.supportsMultiLine(for: selectedCodeTypeString) {
                                TVOSMultilineCodeEditor(
                                    text: $cheatCode,
                                    isFocused: Binding(
                                        get: { focusedField == .code },
                                        set: { focusedField = $0 ? .code : nil }
                                    )
                                )
                                    .frame(minHeight: 100)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.black.opacity(0.5))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(focusedField == .code ? accentColor : accentColor.opacity(0.3), lineWidth: 2)
                                            )
                                    )
                            } else {
                                TextField(CheatCodeValidator.placeholder(for: selectedCodeTypeString), text: $cheatCode)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 28, design: .monospaced))
                                    .foregroundStyle(.white)
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
                            }

                            if !cheatCode.isEmpty {
                                Image(systemName: validationResult.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(validationResult.isValid ? .green : .red)
                                    .transition(.opacity)
                            }
                        }

                        if let hint = CheatCodeValidator.formatHint(for: selectedCodeTypeString) {
                            Text(hint)
                                .font(.system(size: 20))
                                .foregroundStyle(accentColor.opacity(0.7))
                        }

                        if case .invalid(let errorHint) = validationResult, !cheatCode.isEmpty {
                            Text(errorHint)
                                .font(.system(size: 20))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }

                    // Code type selector
                    if cheatTypes.count > 1 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CODE TYPE")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(accentColor)
                            HStack(spacing: 16) {
                                ForEach(Array(cheatTypes.enumerated()), id: \.offset) { index, codeType in
                                    Button(action: { selectedCodeType = index }) {
                                        Text(CheatCodeTypes(string: codeType)?.stringValue ?? codeType)
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundStyle(selectedCodeType == index ? .white : .gray)
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

                HStack(spacing: 40) {
                    Button(action: { dismiss() }) {
                        Text("CANCEL")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 60)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: { saveCheat() }) {
                        Text("SAVE")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
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
                    .disabled(validationResult == .empty)
                    .opacity(validationResult == .empty ? 0.5 : 1.0)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear { focusedField = .name }
    }

    private func saveCheat() {
        let code = cheatCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        let trimmedName = cheatName.trimmingCharacters(in: .whitespaces)
        let name = trimmedName.isEmpty ? "Cheat Code" : trimmedName
        guard !cheat.isInvalidated, let realm = cheat.realm else {
            ELOG("saveCheat: cheat is invalidated or detached from Realm")
            dismiss()
            return
        }
        do {
            try realm.write {
                cheat.code = code
                cheat.type = name
                cheat.codeType = selectedCodeTypeString
            }
            dismiss()
        } catch {
            ELOG("Error saving edited cheat: \(error)")
        }
    }
}

// MARK: - Hosting Controller

public class TVOSCheatsHostingController: UIHostingController<TVOSCheatsView> {
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
        let view = TVOSCheatsView(
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
