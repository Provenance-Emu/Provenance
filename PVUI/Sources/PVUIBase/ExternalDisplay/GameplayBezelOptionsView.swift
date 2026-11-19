#if os(iOS) || os(tvOS)
import Combine
import Defaults
import PVSettings
import PVShaders
import SwiftUI

struct GameplayBezelOptionsView: View {
    let emulatorVC: PVEmulatorViewController
    @Environment(\.dismiss) private var dismiss
    @Default(.externalDisplayBezel) private var bezel
    @Default(.externalDisplayBezelByGame) private var pins
    @Default(.externalDisplayGameBezels) private var gameBezels
    @State private var path: [Destination] = []
    #if os(iOS)
    @State private var input = PauseMenuControllerInput()
    @State private var cursor: Destination = .global
    #endif

    private enum Destination: Hashable { case global, game, automatic, done }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Button(String(localized: "Default Bezel")) { path.append(.global) }
                    .listRowBackground(highlight(.global))
                if emulatorVC.gameplayBezelGame != nil {
                    Button(String(localized: "Bezel for This Game")) { path.append(.game) }
                        .listRowBackground(highlight(.game))
                }
                Section {
                    Toggle(String(localized: "Game Bezels"), isOn: $gameBezels)
                        .listRowBackground(highlight(.automatic))
                } footer: {
                    Text("Automatically look for matching artwork from The Bezel Project.")
                }
                Button(String(localized: "Done")) { dismiss() }
                    .listRowBackground(highlight(.done))
            }
            .navigationTitle(String(localized: "Bezels"))
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .global:
                    TVBezelPickerView(selection: Binding(get: { bezel }, set: { bezel = $0 ?? "" }),
                                      offersSystemAutomatic: true,
                                      controllerCommands: commands)
                case .game:
                    if let game = emulatorVC.gameplayBezelGame {
                        TVBezelPickerView(
                            selection: Binding(get: { pins[game.md5] }, set: { pins[game.md5] = $0 }),
                            allowsAutomatic: true,
                            game: game,
                            controllerCommands: commands
                        )
                    }
                case .automatic, .done:
                    EmptyView()
                }
            }
        }
        .onChange(of: bezel) { _, _ in refresh() }
        .onChange(of: pins) { _, _ in refresh() }
        .onChange(of: gameBezels) { _, _ in refresh() }
        #if os(iOS)
        .onAppear { input.start() }
        .onDisappear { input.stop() }
        .onReceive(input.commands) { command in
            guard path.isEmpty else { return }
            let rows: [Destination] = emulatorVC.gameplayBezelGame == nil
                ? [.global, .automatic, .done] : [.global, .game, .automatic, .done]
            switch command {
            case .up, .down:
                let index = rows.firstIndex(of: cursor) ?? 0
                cursor = rows[min(max(index + (command == .down ? 1 : -1), 0), rows.count - 1)]
            case .activate:
                switch cursor {
                case .global, .game: path.append(cursor)
                case .automatic: gameBezels.toggle()
                case .done: dismiss()
                }
            case .back: dismiss()
            default: break
            }
        }
        #endif
    }

    private var commands: AnyPublisher<PauseMenuNavigationCommand, Never>? {
        #if os(iOS)
        input.commands.eraseToAnyPublisher()
        #else
        nil
        #endif
    }

    private func highlight(_ row: Destination) -> Color? {
        #if os(iOS)
        cursor == row ? Color.accentColor.opacity(0.25) : nil
        #else
        nil
        #endif
    }

    private func refresh() {
        emulatorVC.updateGameplayBezel()
        #if os(iOS)
        emulatorVC.updateExternalDisplay()
        #endif
    }
}
#endif
