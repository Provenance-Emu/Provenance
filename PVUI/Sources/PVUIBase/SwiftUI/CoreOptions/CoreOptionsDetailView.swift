import SwiftUI
import PVCoreBridge
import PVLibrary
import PVThemes

// MARK: - Palette

/// The handful of theme colors the options list needs, resolved once by the
/// screen so individual rows don't each subscribe to `ThemeManager`.
private struct CoreOptionsPalette {
    let background: Color
    let cellBackground: Color
    let title: Color
    let detail: Color
    let header: Color
    let tint: Color
    let isDark: Bool

    init(_ palette: any UXThemePalette) {
        background = Color(palette.gameLibraryBackground)
        cellBackground = (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground))
            .opacity(palette.dark ? 0.6 : 0.9)
        title = palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor
        detail = (palette.settingsCellTextDetail?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor).opacity(0.8)
        header = palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor
        tint = palette.defaultTintColor.swiftUIColor
        isDark = palette.dark
    }
}

// MARK: - Metrics

private enum CoreOptionsMetrics {
    static let sectionCornerRadius: CGFloat = 12
    static let rowCornerRadius: CGFloat = 10
    static let badgeCornerRadius: CGFloat = 4
    /// Descriptions are clipped to this many lines until the row is focused.
    static let collapsedDetailLineLimit = 3
    /// Widest a choice's current value may grow before truncating, so a long
    /// value can't squeeze out the option's title.
    static let valueMaxWidth: CGFloat = 180
}

// MARK: - CoreOptionsDetailView

/// Lists and edits a core's options: grouped by the core's own categories,
/// collapsible, searchable, and — when opened in-game on iOS — fully drivable
/// from a game controller.
public struct CoreOptionsDetailView: View {
    let coreClass: CoreOptional.Type
    let title: String
    /// MD5 hash of the current game. When non-nil a scope picker is shown and
    /// writes/reads default to the per-game key.
    let gameMD5: String?
    /// Closes the screen. Supplied when the list is presented over a paused
    /// game, which is also what turns controller navigation on: a controller is
    /// the only input a player is guaranteed to have there.
    let onClose: (() -> Void)?

    @ObservedObject private var themeManager = ThemeManager.shared

    /// Whether changes apply to this game only (true) or to the whole core.
    /// Only meaningful when `gameMD5` is non-nil.
    @AppStorage(CoreOptionsScope.perGameDefaultsKey) private var perGameScope = true
    @State private var sections: [CoreOptionListSection] = []
    @State private var collapsedSectionIDs: Set<String> = []
    /// Bumped after every write. Rows read their values straight from storage,
    /// so this is what tells SwiftUI those values moved.
    @State private var revision = 0
    @State private var showResetConfirmation = false
    @State private var showResetGameOverridesConfirmation = false
    #if !os(tvOS)
    @State private var query = ""
    /// Row or section header the controller is on.
    @State private var focusedItemID: String?
    @ObservedObject private var gamepadManager = GamepadManager.shared
    @Environment(\.dismiss) private var dismiss
    #endif

    public init(coreClass: CoreOptional.Type, title: String, gameMD5: String? = nil, onClose: (() -> Void)? = nil) {
        self.coreClass = coreClass
        self.title = title
        self.gameMD5 = gameMD5
        self.onClose = onClose
    }

    /// The effective MD5 to use for reads/writes given the current scope selection.
    private var effectiveMD5: String? {
        guard let md5 = gameMD5, !md5.isEmpty, perGameScope else { return nil }
        return md5
    }

    private var store: CoreOptionValueStore {
        CoreOptionValueStore(coreClass: coreClass, md5: effectiveMD5)
    }

    private var palette: CoreOptionsPalette {
        CoreOptionsPalette(themeManager.currentPalette)
    }

    private var hasGameScope: Bool {
        gameMD5?.isEmpty == false
    }

    // MARK: - Body

    public var body: some View {
        content
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(title)
            .onAppear(perform: loadSections)
            .uiKitAlert(
                "Reset All Options",
                message: resetAllMessage,
                isPresented: $showResetConfirmation
            ) {
                UIAlertAction(title: "Reset", style: .destructive) { _ in
                    resetAllOptions()
                    showResetConfirmation = false
                }
                UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    showResetConfirmation = false
                }
            }
            .uiKitAlert(
                "Reset Game Overrides",
                message: "Remove all per-game option overrides for this title? "
                    + "Core-global settings will be used instead.",
                isPresented: $showResetGameOverridesConfirmation
            ) {
                UIAlertAction(title: "Reset", style: .destructive) { _ in
                    resetGameOverrides()
                    showResetGameOverridesConfirmation = false
                }
                UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    showResetGameOverridesConfirmation = false
                }
            }
    }

    private var resetAllMessage: String {
        guard hasGameScope else {
            return "Are you sure you want to reset all options for \(title) to their default values?"
        }
        return "Reset all \(title) global defaults to factory values? "
            + "This affects core-wide defaults; per-game overrides will remain unchanged."
    }

    // MARK: - Data

    private func loadSections() {
        let built = CoreOptionListLayout.sections(from: coreClass.options, generalTitle: String(localized: "General"))
        /// The view reappears when a pushed choice list pops; only a changed
        /// option set should disturb what the user had expanded.
        guard built != sections else { return }
        sections = built
        collapsedSectionIDs = CoreOptionListLayout.initiallyCollapsedSectionIDs(for: built)
    }

    private func didChangeValue() {
        revision &+= 1
    }

    private func toggleCollapsed(_ section: CoreOptionListSection) {
        if collapsedSectionIDs.contains(section.id) {
            collapsedSectionIDs.remove(section.id)
        } else {
            collapsedSectionIDs.insert(section.id)
        }
    }

    private func resetAllOptions() {
        let globalStore = CoreOptionValueStore(coreClass: coreClass, md5: nil)
        for row in sections.flatMap(\.rows) {
            globalStore.reset(row.option)
        }
        didChangeValue()
    }

    private func resetGameOverrides() {
        guard let md5 = gameMD5, !md5.isEmpty else { return }
        let gameStore = CoreOptionValueStore(coreClass: coreClass, md5: md5)
        for row in sections.flatMap(\.rows) where gameStore.hasGameOverride(row.option) {
            gameStore.reset(row.option)
        }
        didChangeValue()
    }

    // MARK: - Reset buttons

    @ViewBuilder
    private var resetButtons: some View {
        if hasGameScope && perGameScope {
            resetButton(title: "RESET GAME OVERRIDES", systemImage: "arrow.counterclockwise.circle", color: .orange) {
                showResetGameOverridesConfirmation = true
            }
        } else {
            resetButton(title: "RESET ALL OPTIONS", systemImage: "arrow.counterclockwise", color: .red) {
                showResetConfirmation = true
            }
        }
    }

    private func resetButton(
        title: LocalizedStringKey,
        systemImage: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundColor(color)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: CoreOptionsMetrics.rowCornerRadius)
                        .fill(color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: CoreOptionsMetrics.rowCornerRadius)
                                .strokeBorder(color.opacity(0.5), lineWidth: 1.5)
                        )
                )
        }
        #if os(tvOS)
        .buttonStyle(TVMediaPlainButtonStyle())
        .tvOSDisableFocusEffect()
        #else
        .buttonStyle(.plain)
        #endif
        .retroSettingsRowFocus(cornerRadius: CoreOptionsMetrics.rowCornerRadius)
    }
}

// MARK: - Touch layout

#if !os(tvOS)
extension CoreOptionsDetailView {

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var visibleSections: [CoreOptionListSection] {
        CoreOptionListLayout.filter(sections, matching: query)
    }

    /// A search shows its matches no matter what was collapsed before it.
    private func isCollapsed(_ section: CoreOptionListSection) -> Bool {
        !isSearching && collapsedSectionIDs.contains(section.id)
    }

    private func headerID(_ section: CoreOptionListSection) -> String {
        "header/\(section.id)"
    }

    /// Controller navigation is offered in-game, where there may be no touch
    /// screen in reach, and only once a pad or keyboard is actually attached.
    private var isControllerNavigationActive: Bool {
        onClose != nil && gamepadManager.isNavigationInputAvailable
    }

    private var content: some View {
        let palette = self.palette
        let store = self.store
        let visible = visibleSections
        return VStack(spacing: 0) {
            controlsHeader(palette: palette)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(visible) { section in
                            SwiftUI.Section {
                                if !isCollapsed(section) {
                                    sectionRows(section, store: store, palette: palette)
                                }
                            } header: {
                                sectionHeader(section, palette: palette)
                                    .id(headerID(section))
                            }
                        }

                        if visible.isEmpty {
                            emptyState(palette: palette)
                        } else {
                            resetButtons
                                .padding(.top, 20)
                                .padding(.bottom, 28)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .scrollDismissesKeyboard(.immediately)
                .onChange(of: focusedItemID) { _, newID in
                    guard let newID else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }

            if isControllerNavigationActive {
                controllerHints(palette: palette)
            }
        }
        .onChange(of: perGameScope) { _, _ in didChangeValue() }
        .onReceive(gamepadManager.eventPublisher, perform: handleGamepadEvent)
    }

    // MARK: Header

    private func controlsHeader(palette: CoreOptionsPalette) -> some View {
        VStack(spacing: 10) {
            if hasGameScope {
                Picker("Scope", selection: $perGameScope) {
                    Text("This Game").tag(true)
                    Text("All Games").tag(false)
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(palette.detail)
                TextField("Search options", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .foregroundColor(palette.title)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(palette.detail)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RetroPauseSearchFieldBackgroundThemed(isDark: palette.isDark))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: Sections

    private func sectionHeader(_ section: CoreOptionListSection, palette: CoreOptionsPalette) -> some View {
        let collapsed = isCollapsed(section)
        let isFocused = focusedItemID == headerID(section)
        return Button {
            guard !isSearching else { return }
            withAnimation(.easeInOut(duration: 0.2)) { toggleCollapsed(section) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .rotationEffect(.degrees(collapsed ? 0 : 90))
                    .opacity(isSearching ? 0 : 1)
                Text(section.title.uppercased())
                    .font(.footnote.weight(.heavy))
                    .tracking(1.2)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(section.rows.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(RetroPauseInsetPillBackground(isDark: palette.isDark))
            }
            .foregroundColor(palette.header)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: CoreOptionsMetrics.rowCornerRadius)
                    .strokeBorder(palette.tint, lineWidth: isFocused ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
        /// Opaque so rows scrolling underneath the pinned header don't show through.
        .background(palette.background)
        .accessibilityHint(collapsed ? "Expands this category" : "Collapses this category")
    }

    private func sectionRows(
        _ section: CoreOptionListSection,
        store: CoreOptionValueStore,
        palette: CoreOptionsPalette
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(section.rows) { row in
                CoreOptionRowView(
                    row: row,
                    store: store,
                    palette: palette,
                    isFocused: focusedItemID == row.id,
                    showsGameOverrideBadge: perGameScope && hasGameScope,
                    revision: revision,
                    onChange: didChangeValue
                )
                .id(row.id)

                if row.id != section.rows.last?.id {
                    Divider()
                        .padding(.leading, 12)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CoreOptionsMetrics.sectionCornerRadius)
                .fill(palette.cellBackground)
        )
        .padding(.bottom, 12)
    }

    private func emptyState(palette: CoreOptionsPalette) -> some View {
        VStack(spacing: 8) {
            Image(systemName: isSearching ? "magnifyingglass" : "slider.horizontal.3")
                .font(.title2)
            Text(isSearching ? "No options match “\(query)”" : "This core has no options")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(palette.detail)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: Controller navigation

    private func controllerHints(palette: CoreOptionsPalette) -> some View {
        HStack(spacing: 14) {
            Label("Move", systemImage: "arrow.up.arrow.down")
            Label("Change", systemImage: "arrow.left.arrow.right")
            Label("Select", systemImage: "a.circle")
            Label("Category", systemImage: "l1.rectangle.roundedbottom")
            Label("Close", systemImage: "b.circle")
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundColor(palette.detail)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(palette.cellBackground)
    }

    /// Every header and visible row, top to bottom — the order focus walks in.
    private func focusOrder() -> [String] {
        visibleSections.flatMap { section in
            [headerID(section)] + (isCollapsed(section) ? [] : section.rows.map(\.id))
        }
    }

    private func handleGamepadEvent(_ event: GamepadEvent) {
        guard isControllerNavigationActive, let command = CoreOptionsControllerCommand(event) else { return }
        switch command {
        case .move(let delta): moveFocus(by: delta)
        case .adjust(let direction): adjustFocusedItem(direction: direction)
        case .activate: activateFocusedItem()
        case .jumpSection(let offset): jumpToSection(offset: offset)
        case .close: close()
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func moveFocus(by delta: Int) {
        let order = focusOrder()
        guard !order.isEmpty else { return }
        guard let current = focusedItemID, let index = order.firstIndex(of: current) else {
            /// First press lands on the first option rather than its header:
            /// changing something is what the user opened the list for.
            focusedItemID = order.first { !$0.hasPrefix("header/") } ?? order.first
            return
        }
        focusedItemID = order[min(order.count - 1, max(0, index + delta))]
    }

    private func focusedSection() -> CoreOptionListSection? {
        guard let focusedItemID else { return nil }
        return visibleSections.first { headerID($0) == focusedItemID || $0.rows.contains { $0.id == focusedItemID } }
    }

    private func focusedRow() -> CoreOptionListRow? {
        guard let focusedItemID else { return nil }
        return visibleSections.lazy.flatMap(\.rows).first { $0.id == focusedItemID }
    }

    private func adjustFocusedItem(direction: Int) {
        if let row = focusedRow() {
            store.adjust(row.option, direction: direction)
            didChangeValue()
        } else if let section = focusedSection(), !isSearching {
            /// On a header, left folds the category and right opens it.
            let shouldCollapse = direction < 0
            guard collapsedSectionIDs.contains(section.id) != shouldCollapse else { return }
            withAnimation(.easeInOut(duration: 0.2)) { toggleCollapsed(section) }
        }
    }

    private func activateFocusedItem() {
        if let row = focusedRow() {
            store.activate(row.option)
            didChangeValue()
        } else if let section = focusedSection(), !isSearching {
            withAnimation(.easeInOut(duration: 0.2)) { toggleCollapsed(section) }
        }
    }

    private func jumpToSection(offset: Int) {
        let visible = visibleSections
        guard !visible.isEmpty else { return }
        guard let current = focusedSection(), let index = visible.firstIndex(where: { $0.id == current.id }) else {
            focusedItemID = headerID(visible[0])
            return
        }
        focusedItemID = headerID(visible[min(visible.count - 1, max(0, index + offset))])
    }
}

/// What a controller press means in the options list. Only presses count;
/// releases map to nothing.
private enum CoreOptionsControllerCommand {
    case move(Int)
    case adjust(Int)
    case activate
    case jumpSection(Int)
    case close

    init?(_ event: GamepadEvent) {
        switch event {
        case .verticalNavigation(let value, true):
            /// Positive is "up" on a stick, which is the previous item.
            self = .move(value > 0 ? -1 : 1)
        case .horizontalNavigation(let value, true):
            self = .adjust(value < 0 ? -1 : 1)
        case .buttonPress(true):
            self = .activate
        case .shoulderLeft(true):
            self = .jumpSection(-1)
        case .shoulderRight(true):
            self = .jumpSection(1)
        case .buttonB(true), .menuToggle(true), .start(true):
            self = .close
        default:
            return nil
        }
    }
}

// MARK: - Touch row

/// One option: its title and description, the control that edits it, and a
/// reset button once the user has changed it.
private struct CoreOptionRowView: View {
    let row: CoreOptionListRow
    let store: CoreOptionValueStore
    let palette: CoreOptionsPalette
    /// Whether the controller is on this row.
    let isFocused: Bool
    let showsGameOverrideBadge: Bool
    /// Changes whenever any value is written; the row's values are read from
    /// storage, so this is its only signal to re-read them.
    let revision: Int
    let onChange: () -> Void

    private var option: CoreOption { row.option }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                label
                Spacer(minLength: 8)
                trailingControl
                if store.isModified(option) {
                    Button {
                        store.reset(option)
                        onChange()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(palette.tint)
                            .frame(minWidth: 28, minHeight: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reset \(row.title)")
                }
            }
            inlineEditor
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: CoreOptionsMetrics.rowCornerRadius)
                .fill(palette.tint.opacity(isFocused ? 0.16 : 0))
                .overlay(
                    RoundedRectangle(cornerRadius: CoreOptionsMetrics.rowCornerRadius)
                        .strokeBorder(palette.tint, lineWidth: isFocused ? 2 : 0)
                )
        )
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(row.title)
                .font(.body.weight(.medium))
                .foregroundColor(palette.title)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = row.detail, !detail.isEmpty {
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(palette.detail)
                    .lineLimit(isFocused ? nil : CoreOptionsMetrics.collapsedDetailLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                if showsGameOverrideBadge && store.hasGameOverride(option) {
                    badge("This game", systemImage: "tag.fill", color: .orange)
                }
                if option.display.requiresRestart {
                    badge("Needs restart", systemImage: "arrow.triangle.2.circlepath", color: .yellow)
                }
            }
        }
    }

    private func badge(_ text: LocalizedStringKey, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: CoreOptionsMetrics.badgeCornerRadius)
                    .fill(color.opacity(0.15))
            )
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch option {
        case .bool:
            ThemedToggle(isOn: Binding(
                get: { store.bool(option) },
                set: { newValue in
                    store.set(newValue, for: option)
                    onChange()
                }
            )) {
                EmptyView()
            }
            .labelsHidden()
            .fixedSize()

        case let .enumeration(_, values, _, _):
            let current = store.int(option)
            choiceMenu {
                ForEach(values, id: \.value) { value in
                    choiceButton(value.title, isSelected: value.value == current) {
                        store.set(value.value, for: option)
                    }
                }
            }

        case let .multi(_, values, _):
            let current = store.multiIndex(option)
            choiceMenu {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    choiceButton(value.title, isSelected: index == current) {
                        store.setMulti(index: index, for: option)
                    }
                }
            }

        case .range, .rangef:
            Text(store.displayValue(option))
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundColor(palette.tint)

        case .string, .group:
            EmptyView()
        }
    }

    /// The current value as a tappable pill opening the full list of choices.
    private func choiceMenu<Choices: View>(@ViewBuilder choices: () -> Choices) -> some View {
        Menu {
            choices()
        } label: {
            HStack(spacing: 4) {
                Text(store.displayValue(option))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(palette.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RetroPauseInsetPillBackground(isDark: palette.isDark))
        }
        .frame(maxWidth: CoreOptionsMetrics.valueMaxWidth, alignment: .trailing)
    }

    private func choiceButton(_ title: String, isSelected: Bool, select: @escaping () -> Void) -> some View {
        Button {
            select()
            onChange()
        } label: {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    @ViewBuilder
    private var inlineEditor: some View {
        switch option {
        case let .range(_, range, _, _):
            RetroWaveSlider(
                value: Binding(
                    get: { Double(store.int(option)) },
                    set: { newValue in
                        store.set(Int(newValue.rounded()), for: option)
                        onChange()
                    }
                ),
                in: Double(range.min)...Double(range.max),
                step: 1.0
            )

        case let .rangef(_, range, _, _):
            RetroWaveSlider(
                value: Binding(
                    get: { Double(store.float(option)) },
                    set: { newValue in
                        store.set(Float(newValue), for: option)
                        onChange()
                    }
                ),
                in: Double(range.min)...Double(range.max),
                step: Double(CoreOptionValueStore.floatStep)
            )

        case .string:
            TextField("Value", text: Binding(
                get: { store.string(option) },
                set: { newValue in
                    store.set(newValue, for: option)
                    onChange()
                }
            ))
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

        default:
            EmptyView()
        }
    }
}
#endif

// MARK: - tvOS layout

#if os(tvOS)
extension CoreOptionsDetailView {

    /// tvOS keeps an eager stack: the focus engine can't see rows a lazy stack
    /// hasn't built yet. Collapsed categories are what keep it small.
    private var content: some View {
        let store = self.store
        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if hasGameScope {
                    scopePicker
                }

                ForEach(sections) { section in
                    let collapsed = collapsedSectionIDs.contains(section.id)
                    VStack(alignment: .leading, spacing: 4) {
                        CoreOptionFocusableRow(
                            action: { withAnimation(.easeInOut(duration: 0.2)) { toggleCollapsed(section) } },
                            content: { tvOSSectionHeader(section, collapsed: collapsed) }
                        )

                        if !collapsed {
                            ForEach(section.rows) { row in
                                tvOSRow(row, store: store)
                            }
                        }
                    }
                }

                resetButtons
                    .padding(.top, 12)
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 30)
        }
        .onChange(of: perGameScope) { _, _ in didChangeValue() }
    }

    private var scopePicker: some View {
        HStack(spacing: 12) {
            ScopePickerButton(title: "This Game", isSelected: perGameScope) {
                perGameScope = true
            }
            ScopePickerButton(title: "All Games", isSelected: !perGameScope) {
                perGameScope = false
            }
        }
    }

    private func tvOSSectionHeader(_ section: CoreOptionListSection, collapsed: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .bold))
                .rotationEffect(.degrees(collapsed ? 0 : 90))
            Text(section.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Spacer()
            CoreOptionValueBadge(text: "\(section.rows.count)")
        }
        .foregroundStyle(CoreOptionsGradient.accent)
    }

    @ViewBuilder
    private func tvOSRow(_ row: CoreOptionListRow, store: CoreOptionValueStore) -> some View {
        let option = row.option
        switch option {
        case .bool:
            CoreOptionFocusableRow(
                action: {
                    store.activate(option)
                    didChangeValue()
                },
                content: { tvOSValueLine(row, store: store) }
            )

        case let .enumeration(_, values, _, _):
            tvOSChoiceRow(
                row,
                store: store,
                choices: values.map { CoreOptionChoiceList.Choice(title: $0.title, detail: $0.description) },
                selectedIndex: values.firstIndex { $0.value == store.int(option) } ?? 0
            ) { index in
                store.set(values[index].value, for: option)
            }

        case let .multi(_, values, _):
            tvOSChoiceRow(
                row,
                store: store,
                choices: values.map { CoreOptionChoiceList.Choice(title: $0.title, detail: $0.description) },
                selectedIndex: store.multiIndex(option)
            ) { index in
                store.setMulti(index: index, for: option)
            }

        case .range, .rangef:
            tvOSStepperRow(row, store: store)

        case .string:
            CoreOptionFocusableRow {
                HStack {
                    tvOSLabel(row, store: store)
                    Spacer()
                    TextField("Value", text: Binding(
                        get: { store.string(option) },
                        set: { newValue in
                            store.set(newValue, for: option)
                            didChangeValue()
                        }
                    ))
                    .frame(maxWidth: 300)
                    .multilineTextAlignment(.trailing)
                }
            }

        case .group:
            EmptyView()
        }
    }

    /// Title on the left, current value on the right.
    ///
    /// Reading `revision` is what makes the line re-read its value after a
    /// write; the value itself lives in storage, not in `@State`.
    private func tvOSValueLine(_ row: CoreOptionListRow, store: CoreOptionValueStore) -> some View {
        HStack {
            tvOSLabel(row, store: store)
            Spacer()
            CoreOptionValueBadge(text: revision >= 0 ? store.displayValue(row.option) : "")
        }
    }

    private func tvOSChoiceRow(
        _ row: CoreOptionListRow,
        store: CoreOptionValueStore,
        choices: [CoreOptionChoiceList.Choice],
        selectedIndex: Int,
        select: @escaping (Int) -> Void
    ) -> some View {
        CoreOptionFocusableNavRow(
            destination: {
                CoreOptionChoiceList(title: row.title, choices: choices, selectedIndex: selectedIndex) { index in
                    select(index)
                    didChangeValue()
                }
            },
            label: { tvOSValueLine(row, store: store) }
        )
    }

    private func tvOSStepperRow(_ row: CoreOptionListRow, store: CoreOptionValueStore) -> some View {
        HStack(spacing: 12) {
            CoreOptionStepper(systemName: "minus") {
                store.adjust(row.option, direction: -1)
                didChangeValue()
            }
            CoreOptionFocusableRow {
                tvOSValueLine(row, store: store)
            }
            CoreOptionStepper(systemName: "plus") {
                store.adjust(row.option, direction: 1)
                didChangeValue()
            }
        }
    }

    private func tvOSLabel(_ row: CoreOptionListRow, store: CoreOptionValueStore) -> some View {
        let palette = self.palette
        return VStack(alignment: .leading, spacing: 4) {
            Text(row.title)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(palette.title)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = row.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 17))
                    .foregroundColor(palette.detail)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if perGameScope && store.hasGameOverride(row.option) {
                Label("Game Override", systemImage: "tag.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - tvOS components

/// A focusable row container that provides retrowave focus styling matching the main settings UI.
/// Renders gradient background, border, and glow shadow when focused via the d-pad.
/// Pass an `action` closure for rows that need tap behavior (e.g. toggling a bool).
private struct CoreOptionFocusableRow<Content: View>: View {
    @FocusState private var isFocused: Bool
    let action: () -> Void
    let content: () -> Content

    init(action: @escaping () -> Void = {}, @ViewBuilder content: @escaping () -> Content) {
        self.action = action
        self.content = content
    }

    var body: some View {
        Button(action: action) {
            content()
        }
        .focused($isFocused)
        .buttonStyle(TVMediaPlainButtonStyle())
        .tvOSDisableFocusEffect()
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .coreOptionFocusChrome(isFocused: isFocused)
    }
}

/// NavigationLink variant with the same retrowave focus styling.
private struct CoreOptionFocusableNavRow<Destination: View, Label: View>: View {
    @FocusState private var isFocused: Bool
    let destination: () -> Destination
    let label: () -> Label

    init(@ViewBuilder destination: @escaping () -> Destination, @ViewBuilder label: @escaping () -> Label) {
        self.destination = destination
        self.label = label
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                label()
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isFocused ? Color.retroPink : Color.white.opacity(0.3))
            }
        }
        .focused($isFocused)
        .buttonStyle(TVMediaPlainButtonStyle())
        .tvOSDisableFocusEffect()
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .coreOptionFocusChrome(isFocused: isFocused)
    }
}

/// The retrowave gradients the tvOS rows are drawn with.
private enum CoreOptionsGradient {
    static let accent = LinearGradient(colors: [.retroPink, .retroBlue], startPoint: .leading, endPoint: .trailing)
    static let value = LinearGradient(colors: [.retroBlue, .retroPurple], startPoint: .leading, endPoint: .trailing)

    static func diagonal(_ start: Color, _ end: Color) -> LinearGradient {
        LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func vertical(_ top: Color, _ bottom: Color) -> LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }
}

private extension View {
    /// Shared focused/unfocused look for option rows: a stroke and a slight
    /// lift rather than a blurred glow, which costs an offscreen pass per row.
    func coreOptionFocusChrome(isFocused: Bool, isSelected: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: CoreOptionsMetrics.sectionCornerRadius, style: .continuous)
        return self
            .background(
                shape.fill(
                    isFocused
                        ? CoreOptionsGradient.diagonal(.retroPink.opacity(0.14), .retroBlue.opacity(0.1))
                        : CoreOptionsGradient.vertical(.white.opacity(isSelected ? 0.05 : 0.03), .white.opacity(0.01))
                )
            )
            .overlay(
                shape.strokeBorder(
                    isFocused
                        ? CoreOptionsGradient.diagonal(.retroPink.opacity(0.8), .retroBlue.opacity(0.6))
                        : CoreOptionsGradient.vertical(.white.opacity(isSelected ? 0.12 : 0.06), .white.opacity(0.02)),
                    lineWidth: isFocused ? 2 : 1
                )
            )
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

/// Value badge used to show current selection in a retroBlue/retroPurple gradient pill.
private struct CoreOptionValueBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold))
            .lineLimit(1)
            .foregroundStyle(CoreOptionsGradient.value)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(CoreOptionsGradient.value.opacity(0.45), lineWidth: 1)
                    )
            )
    }
}

/// Stepper-style +/- button for adjusting range values on tvOS where sliders aren't usable.
private struct CoreOptionStepper: View {
    let systemName: String
    let action: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(CoreOptionsGradient.accent)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(isFocused ? 0.12 : 0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.retroPink.opacity(isFocused ? 0.7 : 0.3), lineWidth: isFocused ? 2 : 1)
                        )
                )
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .focused($isFocused)
        .buttonStyle(TVMediaPlainButtonStyle())
        .tvOSDisableFocusEffect()
    }
}

/// Segmented-picker replacement for tvOS. Mirrors the retrowave focus styling so
/// scope selection doesn't show the default tvOS focus halo / white blow-out.
private struct ScopePickerButton: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? CoreOptionsGradient.accent : CoreOptionsGradient.vertical(.white, .white))
                .opacity(isSelected ? 1 : 0.75)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
        }
        .focused($isFocused)
        .buttonStyle(TVMediaPlainButtonStyle())
        .tvOSDisableFocusEffect()
        .coreOptionFocusChrome(isFocused: isFocused, isSelected: isSelected)
    }
}

/// Full list of an option's choices, pushed from its row.
private struct CoreOptionChoiceList: View {
    struct Choice {
        let title: String
        let detail: String?
    }

    let title: String
    let choices: [Choice]
    let onSelect: (Int) -> Void
    @State private var selectedIndex: Int
    @ObservedObject private var themeManager = ThemeManager.shared

    init(title: String, choices: [Choice], selectedIndex: Int, onSelect: @escaping (Int) -> Void) {
        self.title = title
        self.choices = choices
        self.onSelect = onSelect
        self._selectedIndex = State(initialValue: selectedIndex)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                    CoreOptionChoiceRow(choice: choice, isSelected: index == selectedIndex) {
                        selectedIndex = index
                        onSelect(index)
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 30)
        }
        .background(Color(themeManager.currentPalette.gameLibraryBackground).ignoresSafeArea())
        .navigationTitle(title)
    }
}

/// A focusable choice with a checkmark on the selected one.
private struct CoreOptionChoiceRow: View {
    let choice: CoreOptionChoiceList.Choice
    let isSelected: Bool
    let action: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(choice.title)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isFocused ? .white : Color.primary)

                    /// Libretro choices carry their raw value as the detail; it
                    /// is only worth showing when it says something the title doesn't.
                    if let detail = choice.detail, !detail.isEmpty, detail != choice.title {
                        Text(detail)
                            .font(.system(size: 17))
                            .foregroundStyle(isFocused ? Color.white.opacity(0.8) : Color.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(CoreOptionsGradient.accent)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
        }
        .focused($isFocused)
        .buttonStyle(TVMediaPlainButtonStyle())
        .tvOSDisableFocusEffect()
        .coreOptionFocusChrome(isFocused: isFocused, isSelected: isSelected)
    }
}
#endif
