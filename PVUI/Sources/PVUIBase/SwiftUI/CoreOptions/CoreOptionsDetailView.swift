import SwiftUI
import PVCoreBridge
import PVLibrary
import PVThemes
import PVUIBase

/// View model to manage core options state
private class CoreOptionsState: ObservableObject {
    @Published var selectedValues: [String: Any] = [:]
    @Published var optionValues: [String: Any] = [:]
    @Published var showResetConfirmation: Bool = false
    @Published var showResetGameOverridesConfirmation: Bool = false

    func updateValue(_ value: Any, forKey key: String) {
        selectedValues[key] = value
        optionValues[key] = value
        objectWillChange.send()
    }

    func resetAllValues() {
        selectedValues.removeAll()
        optionValues.removeAll()
        objectWillChange.send()
    }
}

// MARK: - tvOS Focusable Option Row

#if os(tvOS)
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
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isFocused
                        ? LinearGradient(colors: [Color.retroPink.opacity(0.12), Color.retroBlue.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)], startPoint: .top, endPoint: .bottom)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isFocused
                        ? LinearGradient(colors: [Color.retroPink.opacity(0.7), Color.retroBlue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .shadow(color: isFocused ? Color.retroPink.opacity(0.25) : .clear, radius: 12, x: 0, y: 4)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
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
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isFocused
                        ? LinearGradient(colors: [Color.retroPink.opacity(0.12), Color.retroBlue.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)], startPoint: .top, endPoint: .bottom)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isFocused
                        ? LinearGradient(colors: [Color.retroPink.opacity(0.7), Color.retroBlue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .shadow(color: isFocused ? Color.retroPink.opacity(0.25) : .clear, radius: 12, x: 0, y: 4)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

/// Value badge used to show current selection in a retroBlue/retroPurple gradient pill.
private struct CoreOptionValueBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(
                LinearGradient(colors: [.retroBlue, .retroPurple], startPoint: .leading, endPoint: .trailing)
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                LinearGradient(colors: [Color.retroBlue.opacity(0.5), Color.retroPurple.opacity(0.3)], startPoint: .leading, endPoint: .trailing),
                                lineWidth: 1
                            )
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
                .foregroundStyle(LinearGradient(colors: [.retroPink, .retroBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isFocused ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(isFocused ? Color.retroPink.opacity(0.7) : Color.retroPink.opacity(0.3), lineWidth: isFocused ? 2 : 1)
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
#endif

// MARK: - CoreOptionsDetailView

/// View that displays and allows editing of core options for a specific core with RetroWave styling
public struct CoreOptionsDetailView: View {
    let coreClass: CoreOptional.Type
    let title: String
    /// MD5 hash of the current game. When non-nil a scope picker is shown and
    /// writes/reads default to the per-game key.
    let gameMD5: String?
    @StateObject private var viewModel = CoreOptionsViewModel()
    @StateObject private var state = CoreOptionsState()
    @ObservedObject private var themeManager = ThemeManager.shared

    /// Whether the user has chosen per-game scope (true) or core-global scope (false).
    /// Only meaningful when `gameMD5` is non-nil.
    @State private var perGameScope: Bool = true
    @State private var isAnimating = false
    @State private var glowOpacity = 0.0
    @State private var scrollOffset: CGFloat = 0

    public init(coreClass: CoreOptional.Type, title: String, gameMD5: String? = nil) {
        self.coreClass = coreClass
        self.title = title
        self.gameMD5 = gameMD5
    }

    /// The effective MD5 to use for reads/writes given the current scope selection.
    private var effectiveMD5: String? {
        guard let md5 = gameMD5, perGameScope else { return nil }
        return md5
    }

    private struct IdentifiableOption: Identifiable {
        let id = UUID()
        let option: CoreOption
    }

    private struct OptionGroup: Identifiable {
        let id = UUID()
        let title: String
        let options: [IdentifiableOption]

        init(title: String, options: [CoreOption]) {
            self.title = title
            self.options = options.map { IdentifiableOption(option: $0) }
        }
    }

    private var groupedOptions: [OptionGroup] {
        var rootOptions = [CoreOption]()
        var groups = [OptionGroup]()
        var processedOptionKeys = Set<String>()

        coreClass.options.forEach { option in
            if processedOptionKeys.contains(option.key) { return }
            processedOptionKeys.insert(option.key)

            switch option {
            case let .group(display, subOptions):
                subOptions.forEach { processedOptionKeys.insert($0.key) }
                groups.append(OptionGroup(title: display.title, options: subOptions))
            default:
                rootOptions.append(option)
            }
        }

        if !rootOptions.isEmpty {
            groups.insert(OptionGroup(title: "General", options: rootOptions), at: 0)
        }

        return groups
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            Color(themeManager.currentPalette.gameLibraryBackground)
                .edgesIgnoringSafeArea(.all)

            RetroGrid(
                lineSpacing: 20,
                lineColor: themeManager.currentPalette.dark
                    ? themeManager.currentPalette.defaultTintColor.swiftUIColor.opacity(0.07)
                    : themeManager.currentPalette.defaultTintColor.swiftUIColor.opacity(0.05)
            )
            .edgesIgnoringSafeArea(.all)
            .opacity(themeManager.currentPalette.dark ? 0.3 : 0.2)
        }
    }

    // MARK: - Title

    private var titleView: some View {
        Text(title.uppercased())
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(themeManager.currentPalette.gameLibraryHeaderText.swiftUIColor)
            .padding(.top, 20)
            .shadow(color: themeManager.currentPalette.defaultTintColor.swiftUIColor.opacity(glowOpacity), radius: 10, x: 0, y: 0)
    }

    // MARK: - Options List

    private var optionsListView: some View {
        ScrollViewWithOffset(axes: .vertical, offsetChanged: { offset in
            scrollOffset = offset
        }) {
            VStack(spacing: 32) {
                titleView

                if gameMD5 != nil {
                    scopePickerView
                }

                ForEach(groupedOptions) { group in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(group.title)
                            #if os(tvOS)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.retroPink, .retroBlue], startPoint: .leading, endPoint: .trailing)
                            )
                            .padding(.horizontal, 4)
                            #else
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.currentPalette.settingsHeaderText?.swiftUIColor ?? themeManager.currentPalette.defaultTintColor.swiftUIColor)
                            .padding(.horizontal)
                            .shadow(color: (themeManager.currentPalette.settingsHeaderText?.swiftUIColor ?? themeManager.currentPalette.defaultTintColor.swiftUIColor).opacity(glowOpacity * 0.5), radius: 4, x: 0, y: 0)
                            #endif

                        #if os(tvOS)
                        VStack(spacing: 4) {
                            ForEach(group.options) { identifiableOption in
                                optionView(for: identifiableOption.option)
                            }
                        }
                        #else
                        VStack(spacing: 16) {
                            ForEach(group.options) { identifiableOption in
                                optionView(for: identifiableOption.option)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    (themeManager.currentPalette.settingsCellBackground?.swiftUIColor ?? Color(themeManager.currentPalette.gameLibraryBackground))
                                        .opacity(themeManager.currentPalette.dark ? 0.6 : 0.9)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    (themeManager.currentPalette.defaultTintColor.swiftUIColor).opacity(themeManager.currentPalette.dark ? 0.7 : 0.5),
                                                    (themeManager.currentPalette.settingsHeaderText?.swiftUIColor ?? themeManager.currentPalette.defaultTintColor.swiftUIColor).opacity(themeManager.currentPalette.dark ? 0.7 : 0.5)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                        )
                        #endif
                    }
                    .padding(.horizontal, 16)
                }

                // Reset all game overrides button (only shown in per-game scope)
                if gameMD5 != nil && perGameScope {
                    Button(action: {
                        state.showResetGameOverridesConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle")
                                .foregroundColor(.orange)
                            Text("RESET GAME OVERRIDES")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 30)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.orange.opacity(0.5), lineWidth: 2)
                                )
                        )
                    }
                    .retroSettingsRowFocus(cornerRadius: 8)
                    #if os(tvOS)
                    .tvOSDisableFocusEffect()
                    .buttonStyle(TVMediaPlainButtonStyle())
                    #endif
                    .padding(.horizontal)
                }

                // Reset all global options — hidden when viewing per-game scope to prevent
                // accidentally wiping global defaults while per-game overrides are active.
                // Users in per-game scope should use "RESET GAME OVERRIDES" above instead.
                if !(gameMD5 != nil && perGameScope) {
                Button(action: {
                    state.showResetConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        Text("RESET ALL OPTIONS")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 30)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                (themeManager.currentPalette.settingsCellBackground?.swiftUIColor ?? Color(themeManager.currentPalette.gameLibraryBackground))
                                    .opacity(themeManager.currentPalette.dark ? 0.7 : 0.9)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.red.opacity(themeManager.currentPalette.dark ? 0.7 : 0.5),
                                                themeManager.currentPalette.defaultTintColor.swiftUIColor
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    )
                    .shadow(color: themeManager.currentPalette.defaultTintColor.swiftUIColor.opacity(0.3), radius: 5)
                }
                .retroSettingsRowFocus(cornerRadius: 8)
                #if os(tvOS)
                .tvOSDisableFocusEffect()
                .buttonStyle(TVMediaPlainButtonStyle())
                #endif
                .padding(.vertical, 20)
                .padding(.horizontal)
                } // end if !(gameMD5 != nil && perGameScope)
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            backgroundView
            optionsListView
        }
        .navigationTitle(title)
        .onAppear {
            loadOptionValues()
        }
        .uiKitAlert(
            "Reset All Options",
            message: gameMD5 != nil
                ? "Reset all \(title) global defaults to factory values? This affects all games."
                : "Are you sure you want to reset all options for \(title) to their default values?",
            isPresented: $state.showResetConfirmation
        ) {
            UIAlertAction(title: "Reset", style: .destructive) { _ in
                resetAllOptions()
                state.showResetConfirmation = false
            }

            UIAlertAction(title: "Cancel", style: .cancel) { _ in
                state.showResetConfirmation = false
            }
        }
        .uiKitAlert(
            "Reset Game Overrides",
            message: "Remove all per-game option overrides for this title? Core defaults will be used instead.",
            isPresented: $state.showResetGameOverridesConfirmation
        ) {
            UIAlertAction(title: "Reset", style: .destructive) { _ in
                if let md5 = gameMD5 {
                    coreClass.resetAllOptions(forMD5: md5)
                    state.resetAllValues()
                    loadOptionValues()
                }
                state.showResetGameOverridesConfirmation = false
            }

            UIAlertAction(title: "Cancel", style: .cancel) { _ in
                state.showResetGameOverridesConfirmation = false
            }
        }
    }

    // MARK: - Scope Picker

    private var scopePickerView: some View {
        Picker("Scope", selection: $perGameScope) {
            Text("This Game").tag(true)
            Text("All Games").tag(false)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .onChange(of: perGameScope) { _ in
            state.resetAllValues()
            loadOptionValues()
        }
    }

    // MARK: - Data Helpers

    private func loadOptionValues() {
        for group in groupedOptions {
            for identifiableOption in group.options {
                let value = getCurrentValue(for: identifiableOption.option)
                if let value = value {
                    state.optionValues[identifiableOption.option.key] = value
                }
            }
        }
    }

    private func resetAllOptions() {
        coreClass.resetAllOptions()
        state.resetAllValues()
        loadOptionValues()
    }

    private func getCurrentValue(for option: CoreOption) -> Any? {
        let md5 = effectiveMD5
        switch option {
        case .bool(_, let defaultValue, _):
            return coreClass.storedValueForOption(Bool.self, option.key, andMD5: md5) ?? defaultValue
        case .string(_, let defaultValue, _):
            return coreClass.storedValueForOption(String.self, option.key, andMD5: md5) ?? defaultValue
        case .enumeration(_, _, let defaultValue, _):
            return coreClass.storedValueForOption(Int.self, option.key, andMD5: md5) ?? defaultValue
        case .range(_, _, let defaultValue, _):
            return coreClass.storedValueForOption(Int.self, option.key, andMD5: md5) ?? defaultValue
        case .rangef(_, _, let defaultValue, _):
            return coreClass.storedValueForOption(Float.self, option.key, andMD5: md5) ?? defaultValue
        case .multi(_, let values, _):
            return coreClass.storedValueForOption(String.self, option.key, andMD5: md5) ?? values.first?.title
        case .group(_, _):
            return nil
        @unknown default:
            return nil
        }
    }

    private func setValue(_ value: Any, for option: CoreOption) {
        state.optionValues[option.key] = value
        let md5 = effectiveMD5

        switch value {
        case let boolValue as Bool:
            coreClass.setValue(boolValue, forOption: option, andMD5: md5)
        case let stringValue as String:
            coreClass.setValue(stringValue, forOption: option, andMD5: md5)
        case let intValue as Int:
            coreClass.setValue(intValue, forOption: option, andMD5: md5)
        case let floatValue as Float:
            coreClass.setValue(floatValue, forOption: option, andMD5: md5)
        default:
            WLOG("📱 Warning: Unhandled value type: \(type(of: value))")
            break
        }
    }

    private func resetOption(_ option: CoreOption) {
        if let md5 = effectiveMD5 {
            coreClass.resetOption(option, forMD5: md5)
            let value = getCurrentValue(for: option)
            state.optionValues[option.key] = value
            state.selectedValues[option.key] = value
        } else if let defaultValue = option.defaultValue {
            setValue(defaultValue, for: option)
            state.optionValues[option.key] = defaultValue
            state.selectedValues[option.key] = defaultValue
        }
    }

    /// Returns true if the option has a per-game override for the current `gameMD5`.
    private func hasPerGameOverride(for option: CoreOption) -> Bool {
        guard let md5 = gameMD5 else { return false }
        return coreClass.hasPerGameOverride(for: option, md5: md5)
    }

    // MARK: - Option Row Builders

    @ViewBuilder
    private func optionView(for option: CoreOption) -> some View {
        VStack(spacing: 2) {
            switch option {
            case let .bool(display, defaultValue, _):
                boolOptionView(display: display, defaultValue: defaultValue, option: option)

            case let .enumeration(display, values, defaultValue, _):
                enumOptionView(display: display, values: values, defaultValue: defaultValue, option: option)

            case let .range(display, range, defaultValue, _):
                rangeOptionView(display: display, range: range, defaultValue: defaultValue, option: option)

            case let .rangef(display, range, defaultValue, _):
                rangefOptionView(display: display, range: range, defaultValue: defaultValue, option: option)

            case let .multi(display, values, _):
                multiOptionView(display: display, values: values, option: option)

            case let .string(display, defaultValue, _):
                stringOptionView(display: display, defaultValue: defaultValue, option: option)

            case .group(_, _):
                EmptyView()
            }

            // Per-game override badge (only shown in per-game scope)
            if perGameScope && hasPerGameOverride(for: option) {
                HStack {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 9))
                    Text("Game Override")
                        .font(.system(size: 10, weight: .medium))
                    Spacer()
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
        }
    }

    // MARK: Bool

    @ViewBuilder
    private func boolOptionView(display: CoreOptionValueDisplay, defaultValue: Bool, option: CoreOption) -> some View {
        #if os(tvOS)
        CoreOptionFocusableRow(action: {
            let current = state.optionValues[option.key] as? Bool ?? defaultValue
            setValue(!current, for: option)
        }) {
            HStack {
                optionLabel(title: display.title, description: display.description)
                Spacer()
                ThemedToggle(isOn: Binding(
                    get: { state.optionValues[option.key] as? Bool ?? defaultValue },
                    set: { setValue($0, for: option) }
                )) {
                    EmptyView()
                }
                .allowsHitTesting(false)
            }
        }
        #else
        HStack {
            optionLabel(title: display.title, description: display.description)
                .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
            Spacer()
            ThemedToggle(isOn: Binding(
                get: { state.optionValues[option.key] as? Bool ?? defaultValue },
                set: { setValue($0, for: option) }
            )) {
                EmptyView()
            }
            Button(action: { resetOption(option) }) {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                    .font(.system(size: 14))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, 8)
        }
        .frame(maxWidth: .infinity)
        #endif
    }

    // MARK: Enumeration

    @ViewBuilder
    private func enumOptionView(display: CoreOptionValueDisplay, values: [CoreOptionEnumValue], defaultValue: Int, option: CoreOption) -> some View {
        let selection = Binding(
            get: { state.selectedValues[option.key] as? Int ?? state.optionValues[option.key] as? Int ?? defaultValue },
            set: { newValue in
                withAnimation {
                    setValue(newValue, for: option)
                    state.updateValue(newValue, forKey: option.key)
                }
            }
        )

        #if os(tvOS)
        CoreOptionFocusableNavRow {
            EnumerationSelectionList(values: values, selection: selection, title: display.title)
        } label: {
            HStack {
                optionLabel(title: display.title, description: display.description)
                Spacer()
                CoreOptionValueBadge(text: values.first { $0.value == selection.wrappedValue }?.title ?? "")
            }
        }
        #else
        HStack {
            NavigationLink {
                EnumerationSelectionList(values: values, selection: selection, title: display.title)
            } label: {
                HStack {
                    optionLabel(title: display.title, description: display.description)
                        .frame(minWidth: 120, alignment: .leading)
                    Spacer()
                    Text(values.first { $0.value == selection.wrappedValue }?.title ?? "")
                        .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                        .font(.system(size: 14))
                    Image(systemName: "chevron.right")
                        .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                        .font(.system(size: 14, weight: .bold))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { resetOption(option) }) {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                    .font(.system(size: 14))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, 8)
        }
        .frame(maxWidth: .infinity)
        #endif
    }

    // MARK: Range (Int)

    @ViewBuilder
    private func rangeOptionView(display: CoreOptionValueDisplay, range: CoreOptionRange<Int>, defaultValue: Int, option: CoreOption) -> some View {
        let currentValue = state.optionValues[option.key] as? Int ?? defaultValue

        #if os(tvOS)
        HStack(spacing: 12) {
            CoreOptionStepper(systemName: "minus") {
                let newVal = max(range.min, currentValue - 1)
                setValue(newVal, for: option)
            }

            CoreOptionFocusableRow {
                HStack {
                    optionLabel(title: display.title, description: display.description)
                    Spacer()
                    CoreOptionValueBadge(text: "\(currentValue)")
                }
            }

            CoreOptionStepper(systemName: "plus") {
                let newVal = min(range.max, currentValue + 1)
                setValue(newVal, for: option)
            }
        }
        #else
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                optionLabel(title: display.title, description: display.description)
                    .frame(minWidth: 180, alignment: .leading)
                Spacer()
                Text("\(currentValue)")
                    .font(.headline)
                    .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                Button(action: { resetOption(option) }) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 8)
            }

            RetroWaveSlider(
                value: Binding(
                    get: { Double(currentValue) },
                    set: { setValue(Int($0), for: option) }
                ),
                in: Double(range.min)...Double(range.max),
                step: 1.0
            )

            HStack {
                Text("\(range.min)")
                    .font(.caption)
                    .foregroundColor(themeManager.currentPalette.settingsHeaderText?.swiftUIColor ?? themeManager.currentPalette.defaultTintColor.swiftUIColor)
                Spacer()
                Text("\(range.max)")
                    .font(.caption)
                    .foregroundColor(themeManager.currentPalette.settingsHeaderText?.swiftUIColor ?? themeManager.currentPalette.defaultTintColor.swiftUIColor)
            }
        }
        .frame(maxWidth: .infinity)
        #endif
    }

    // MARK: Range (Float)

    @ViewBuilder
    private func rangefOptionView(display: CoreOptionValueDisplay, range: CoreOptionRange<Float>, defaultValue: Float, option: CoreOption) -> some View {
        let currentValue = state.optionValues[option.key] as? Float ?? defaultValue

        #if os(tvOS)
        HStack(spacing: 12) {
            CoreOptionStepper(systemName: "minus") {
                let newVal = max(range.min, currentValue - 0.1)
                setValue(newVal, for: option)
            }

            CoreOptionFocusableRow {
                HStack {
                    optionLabel(title: display.title, description: display.description)
                    Spacer()
                    CoreOptionValueBadge(text: String(format: "%.1f", currentValue))
                }
            }

            CoreOptionStepper(systemName: "plus") {
                let newVal = min(range.max, currentValue + 0.1)
                setValue(newVal, for: option)
            }
        }
        #else
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                optionLabel(title: display.title, description: display.description)
                    .frame(minWidth: 120, alignment: .leading)
                Spacer()
                Text(String(format: "%.1f", currentValue))
                    .font(.headline)
                    .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                Button(action: { resetOption(option) }) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 8)
            }

            RetroWaveSlider(
                value: Binding(
                    get: { Double(currentValue) },
                    set: { setValue(Float($0), for: option) }
                ),
                in: Double(range.min)...Double(range.max),
                step: 0.1
            )

            HStack {
                Text(String(format: "%.1f", range.min))
                    .font(.caption)
                    .foregroundColor(themeManager.currentPalette.settingsHeaderText?.swiftUIColor ?? themeManager.currentPalette.defaultTintColor.swiftUIColor)
                Spacer()
                Text(String(format: "%.1f", range.max))
                    .font(.caption)
                    .foregroundColor(themeManager.currentPalette.settingsHeaderText?.swiftUIColor ?? themeManager.currentPalette.defaultTintColor.swiftUIColor)
            }
        }
        .frame(maxWidth: .infinity)
        #endif
    }

    // MARK: Multi

    @ViewBuilder
    private func multiOptionView(display: CoreOptionValueDisplay, values: [CoreOptionMultiValue], option: CoreOption) -> some View {
        let selection = Binding(
            get: { state.selectedValues[option.key] as? String ?? state.optionValues[option.key] as? String ?? values.first?.title ?? "" },
            set: { newValue in
                withAnimation {
                    setValue(newValue, for: option)
                    state.updateValue(newValue, forKey: option.key)
                }
            }
        )

        #if os(tvOS)
        CoreOptionFocusableNavRow {
            MultiSelectionList(values: values, selection: selection, title: display.title)
        } label: {
            HStack {
                optionLabel(title: display.title, description: display.description)
                Spacer()
                CoreOptionValueBadge(text: selection.wrappedValue)
            }
        }
        #else
        HStack {
            NavigationLink {
                MultiSelectionList(values: values, selection: selection, title: display.title)
            } label: {
                VStack(alignment: .leading) {
                    Text(display.title)
                        .foregroundColor(themeManager.currentPalette.settingsCellText?.swiftUIColor ?? themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    if let description = display.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor((themeManager.currentPalette.settingsCellTextDetail?.swiftUIColor ?? themeManager.currentPalette.defaultTintColor.swiftUIColor))
                    }
                    Text(selection.wrappedValue)
                        .foregroundColor((themeManager.currentPalette.settingsCellTextDetail?.swiftUIColor ?? themeManager.currentPalette.defaultTintColor.swiftUIColor))
                }
            }
            Spacer()
            Button(action: { resetOption(option) }) {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
            }
            .buttonStyle(.borderless)
        }
        #endif
    }

    // MARK: String

    @ViewBuilder
    private func stringOptionView(display: CoreOptionValueDisplay, defaultValue: String, option: CoreOption) -> some View {
        #if os(tvOS)
        CoreOptionFocusableRow {
            HStack {
                optionLabel(title: display.title, description: display.description)
                Spacer()
                TextField("Value", text: Binding(
                    get: { state.optionValues[option.key] as? String ?? defaultValue },
                    set: { setValue($0, for: option) }
                ))
                .frame(maxWidth: 300)
                .multilineTextAlignment(.trailing)
            }
        }
        #else
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(display.title)
                        .foregroundColor(themeManager.currentPalette.settingsCellText?.swiftUIColor ?? themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    if let description = display.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor((themeManager.currentPalette.settingsCellTextDetail?.swiftUIColor ?? themeManager.currentPalette.defaultTintColor.swiftUIColor))
                    }
                }
                Spacer()
                Button(action: { resetOption(option) }) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                }
                .buttonStyle(.borderless)
            }

            TextField("Value", text: Binding(
                get: { state.optionValues[option.key] as? String ?? defaultValue },
                set: { setValue($0, for: option) }
            ))
            .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        #endif
    }

    // MARK: - Shared Label Builder

    @ViewBuilder
    private func optionLabel(title: String, description: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                #if os(tvOS)
                .font(.system(size: 20, weight: .medium))
                #else
                .font(.system(size: 16, weight: .medium))
                #endif
                .foregroundColor(themeManager.currentPalette.settingsCellText?.swiftUIColor ?? themeManager.currentPalette.gameLibraryText.swiftUIColor)
                .fixedSize(horizontal: false, vertical: true)

            if let description = description {
                Text(description)
                    #if os(tvOS)
                    .font(.system(size: 15))
                    #else
                    .font(.caption)
                    #endif
                    .foregroundColor((themeManager.currentPalette.settingsCellTextDetail?.swiftUIColor ?? themeManager.currentPalette.defaultTintColor.swiftUIColor).opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Selection List Views

private struct EnumerationSelectionList: View {
    let values: [CoreOptionEnumValue]
    @Binding var selection: Int
    let title: String
    @State private var selectedValue: Int
    @ObservedObject private var themeManager = ThemeManager.shared

    init(values: [CoreOptionEnumValue], selection: Binding<Int>, title: String) {
        self.values = values
        self._selection = selection
        self.title = title
        self._selectedValue = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        #if os(tvOS)
        ZStack {
            Color(themeManager.currentPalette.gameLibraryBackground)
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(values, id: \.value) { value in
                        SelectionRowButton(
                            title: value.title,
                            description: value.description,
                            isSelected: value.value == selectedValue
                        ) {
                            withAnimation {
                                selectedValue = value.value
                                selection = value.value
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(title)
        .onAppear { selectedValue = selection }
        .onChange(of: selection) { newValue in selectedValue = newValue }
        #else
        List {
            ForEach(values, id: \.value) { value in
                Button {
                    withAnimation {
                        selectedValue = value.value
                        selection = value.value
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(value.title)
                            if let description = value.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if value.value == selectedValue {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .onAppear { selectedValue = selection }
        .onChange(of: selection) { newValue in selectedValue = newValue }
        #endif
    }
}

private struct MultiSelectionList: View {
    let values: [CoreOptionMultiValue]
    @Binding var selection: String
    let title: String
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        #if os(tvOS)
        ZStack {
            Color(themeManager.currentPalette.gameLibraryBackground)
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(values, id: \.title) { value in
                        SelectionRowButton(
                            title: value.title,
                            description: value.description,
                            isSelected: value.title == selection
                        ) {
                            withAnimation { selection = value.title }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(title)
        #else
        List {
            ForEach(values, id: \.title) { value in
                Button {
                    withAnimation { selection = value.title }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(value.title)
                            if let description = value.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if value.title == selection {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        #endif
    }
}

// MARK: - tvOS Selection Row

#if os(tvOS)
/// A focusable selection row for enum/multi lists on tvOS with retrowave focus styling
/// and a checkmark indicator for the currently selected value.
private struct SelectionRowButton: View {
    let title: String
    let description: String?
    let isSelected: Bool
    let action: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isFocused ? .white : Color.primary)

                    if let description = description {
                        Text(description)
                            .font(.system(size: 15))
                            .foregroundStyle(isFocused ? Color.white.opacity(0.8) : Color.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            LinearGradient(colors: [.retroPink, .retroBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
        }
        .focused($isFocused)
        .buttonStyle(TVMediaPlainButtonStyle())
        .tvOSDisableFocusEffect()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isFocused
                        ? LinearGradient(colors: [Color.retroPink.opacity(0.12), Color.retroBlue.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(isSelected ? 0.04 : 0.02), Color.white.opacity(0.01)], startPoint: .top, endPoint: .bottom)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isFocused
                        ? LinearGradient(colors: [Color.retroPink.opacity(0.7), Color.retroBlue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(isSelected ? 0.1 : 0.04), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom),
                    lineWidth: isFocused ? 2 : (isSelected ? 1.5 : 1)
                )
        )
        .shadow(color: isFocused ? Color.retroPink.opacity(0.25) : .clear, radius: 12, x: 0, y: 4)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}
#endif
