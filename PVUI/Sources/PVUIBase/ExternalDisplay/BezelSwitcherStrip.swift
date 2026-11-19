//
//  BezelSwitcherStrip.swift
//  PVUI
//
//  The pause menu's TV switcher: a strip over the paused game, which shows each TV as it is
//  stepped onto.
//

#if os(iOS) || os(tvOS)
import Combine
import Defaults
import PVSettings
import SwiftUI

/// The strip itself: the list of TVs and its buttons. It owns nothing; `BezelSwitcherHost`
/// holds the model and does the saving.
struct BezelSwitcherStrip: View {
    @Binding var model: BezelSwitcherModel
    /// What an item is called: "Off", "Automatic · Living Room TV", a TV's name, "More…".
    let name: (BezelSwitcherModel.Item) -> String
    let isLoading: Bool
    let showsThisGameOnly: Bool
    /// Name the controller's buttons beside the actions.
    let showsControllerHints: Bool
    let onKeep: () -> Void
    let onCancel: () -> Void
    let onMore: () -> Void

    #if os(tvOS)
    @FocusState private var focusedItem: String?
    #endif

    var body: some View {
        VStack(spacing: 10) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.items) { item in
                            chip(item).id(item.id)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .onAppear { proxy.scrollTo(model.selection.id, anchor: .center) }
                .onChange(of: model.selection.id) { _, id in
                    withAnimation(.easeInOut(duration: 0.15)) { proxy.scrollTo(id, anchor: .center) }
                }
            }
            HStack(spacing: 12) {
                action(String(localized: "Keep"), hint: "a.circle", perform: onKeep)
                action(String(localized: "Cancel"), hint: "b.circle", perform: onCancel)
                if showsThisGameOnly {
                    action(model.thisGameOnly ? String(localized: "This game only: On") : String(localized: "This game only: Off"),
                           hint: "y.circle") { model.thisGameOnly.toggle() }
                }
                action(model.lightsRoom ? String(localized: "Room light: On") : String(localized: "Room light: Off"),
                       hint: "x.circle") { model.lightsRoom.toggle() }
                Spacer(minLength: 0)
                if isLoading { ProgressView() }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(.regularMaterial)
        #if os(tvOS)
        .onAppear { focusedItem = model.selection.id }
        .onChange(of: focusedItem) { _, id in
            if let id { model.select(id: id) }
        }
        .onExitCommand(perform: onCancel)
        #endif
    }

    private func chip(_ item: BezelSwitcherModel.Item) -> some View {
        let isSelected = model.selection.id == item.id
        let button = Button {
            if item.group == .more {
                onMore()
            } else {
                #if os(tvOS)
                // Focus already chose it; Select keeps it.
                onKeep()
                #else
                model.select(id: item.id)
                #endif
            }
        } label: {
            Text(name(item))
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        #if os(tvOS)
        return button.focused($focusedItem, equals: item.id)
        #else
        return button
            .buttonStyle(.plain)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), in: Capsule())
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        #endif
    }

    private func action(_ title: String, hint: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            if showsControllerHints {
                Label(title, systemImage: hint)
            } else {
                Text(title)
            }
        }
        .buttonStyle(.bordered)
    }
}

/// The switcher as the pause menu shows it: builds the list for the running game, previews
/// the selection on the game behind it, and saves on Keep. Nothing is saved while browsing.
struct BezelSwitcherHost: View {
    let emulatorVC: PVEmulatorViewController
    /// The pause menu's controller input on iOS; tvOS moves focus instead.
    let commands: AnyPublisher<PauseMenuNavigationCommand, Never>?
    /// The strip is done (kept or cancelled): go back to the pause menu.
    let onClose: () -> Void
    /// Open the bezel library in the strip's place.
    let onMore: () -> Void

    @State private var model: BezelSwitcherModel
    @State private var isLoading = false

    /// How long a selection must rest before the game behind is redrawn in it, so holding a
    /// direction does not load every TV passed over.
    private static let previewDelay: Duration = .milliseconds(150)
    /// How often the loading mark and the "can a TV still show" check are refreshed.
    private static let pollInterval: TimeInterval = 0.25

    init(emulatorVC: PVEmulatorViewController, commands: AnyPublisher<PauseMenuNavigationCommand, Never>?,
         onClose: @escaping () -> Void, onMore: @escaping () -> Void) {
        self.emulatorVC = emulatorVC
        self.commands = commands
        self.onClose = onClose
        self.onMore = onMore
        let pinned = emulatorVC.pinnedBezelID
        _model = State(initialValue: BezelSwitcherModel(
            builtIn: TVBezelCatalog.bundled.map(\.id),
            shaderPresets: TVBezelCatalog.shaderPresets.map(\.id),
            yours: TVBezelLibrary.shared.listed.map(\.id),
            current: pinned ?? Defaults[.externalDisplayBezel],
            gameHasPin: pinned != nil,
            lightsRoom: TVBezelRoomLight.isOn))
    }

    private struct PreviewKey: Equatable {
        let id: String
        let lightsRoom: Bool
    }

    var body: some View {
        BezelSwitcherStrip(model: $model,
                           name: name,
                           isLoading: isLoading,
                           showsThisGameOnly: emulatorVC.shaderGameMD5 != nil,
                           showsControllerHints: commands != nil && PVControllerManager.shared.hasControllers,
                           onKeep: keep,
                           onCancel: cancel,
                           onMore: more)
            .task(id: PreviewKey(id: model.selection.id, lightsRoom: model.lightsRoom)) {
                try? await Task.sleep(for: Self.previewDelay)
                guard !Task.isCancelled, model.selection.group != .more else { return }
                emulatorVC.bezelPreview = .init(choice: model.selection.id, lightsRoom: model.lightsRoom)
            }
            .onReceive(Timer.publish(every: Self.pollInterval, on: .main, in: .common).autoconnect()) { _ in
                // Rotated to portrait, a skin applied, the light gun raised: no TV can show now.
                guard emulatorVC.offersBezelSwitcher else { return cancel() }
                isLoading = (emulatorVC.gpuViewController as? PVMetalViewController)?.isLocalBezelLoading ?? false
            }
            .onReceive(commands ?? Empty().eraseToAnyPublisher()) { handle($0) }
    }

    private func name(_ item: BezelSwitcherModel.Item) -> String {
        switch item.id {
        case ExternalDisplayBezelRules.noBezelID:
            return String(localized: "Off")
        case ExternalDisplayBezelRules.automaticBezelID:
            let automatic = TVBezelCatalog.resolve(chosen: item.id,
                                                   matchesSystem: Defaults[.externalDisplayBezelMatchesSystem],
                                                   systemID: emulatorVC.shaderSystemID,
                                                   systemSuitsTV: emulatorVC.systemSuitsTV)
            if let bezel = automatic.bezel {
                return String(localized: "Automatic · \(bezel.name)")
            }
            return String(localized: "Automatic · none for this system")
        case BezelSwitcherModel.moreID:
            return String(localized: "More…")
        default:
            return TVBezelCatalog.bezel(id: item.id)?.name ?? item.id
        }
    }

    /// Inside the strip the pad's buttons mean the strip's actions: X is room light and Y is
    /// "this game only" (not quick save and load), L1 and R1 jump between groups.
    private func handle(_ command: PauseMenuNavigationCommand) {
        switch command {
        case .left: model.step(-1)
        case .right: model.step(1)
        case .previousTab: model.jumpGroup(-1)
        case .nextTab: model.jumpGroup(1)
        case .activate: keep()
        case .back: cancel()
        case .quickSave: model.lightsRoom.toggle()
        case .quickLoad:
            if emulatorVC.shaderGameMD5 != nil { model.thisGameOnly.toggle() }
        case .up, .down: break
        }
    }

    private func keep() {
        guard let commit = model.commit(gameHasPin: emulatorVC.pinnedBezelID != nil) else { return more() }
        if let chosen = commit.chosen { Defaults[.externalDisplayBezel] = chosen }
        if let md5 = emulatorVC.shaderGameMD5 {
            switch commit.pin {
            case .set(let id): Defaults[.externalDisplayBezelByGame][md5] = id
            case .remove: Defaults[.externalDisplayBezelByGame][md5] = nil
            case .unchanged: break
            }
        }
        // Only a change is stored: an untouched setting keeps going by the device.
        if commit.lightsRoom != TVBezelRoomLight.isOn { TVBezelRoomLight.set(commit.lightsRoom) }
        emulatorVC.bezelPreview = nil
        onClose()
    }

    private func cancel() {
        emulatorVC.bezelPreview = nil
        onClose()
    }

    private func more() {
        emulatorVC.bezelPreview = nil
        onMore()
    }
}
#endif
