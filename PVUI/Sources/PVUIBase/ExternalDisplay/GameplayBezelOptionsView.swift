#if os(iOS) || os(tvOS)
import Combine
import Defaults
import PVSettings
import PVShaders
import SwiftUI

extension PVEmulatorViewController {
    var canShowGameplayBezels: Bool {
        guard filtersApplyToCurrentLayout, hostGPUViewDrawsGame,
              (gpuViewController as? PVMetalViewController)?.presentsCoreFrames == true else { return false }
        #if os(iOS)
        return PVControllerManager.shared.hasControllers
        #else
        return true
        #endif
    }

    var gameplayBezelGame: ExternalDisplayGameContext? {
        guard let game, !game.isInvalidated, let systemID = shaderSystemID else { return nil }
        let rom = (game.romPath as NSString).lastPathComponent as NSString
        return ExternalDisplayGameContext(md5: game.md5Hash, systemID: systemID, romName: rom.deletingPathExtension, title: game.title)
    }

    /// Resolves the same bezel choice on Apple TV and controller-driven iOS gameplay.
    func updateGameplayBezel() {
        guard let renderer = gpuViewController as? PVMetalViewController else { return }
        let pinned = shaderGameMD5.flatMap { Defaults[.externalDisplayBezelByGame][$0] }
        let gameBezels = Defaults[.externalDisplayGameBezels]
        let artwork = ExternalDisplayGameArtwork.shared
        let bezel = canShowGameplayBezels ? TVBezelCatalog.bezel(
            chosen: Defaults[.externalDisplayBezel],
            matchesSystem: Defaults[.externalDisplayBezelMatchesSystem],
            systemID: shaderSystemID,
            pinned: pinned,
            gameArt: gameBezels ? artwork.bezelID(forGame: shaderGameMD5) : nil
        ) : nil
        let store = ShaderLibraryStore.shared
        let selected = store.resolvedShader(gameMD5: shaderGameMD5, systemID: shaderSystemID, screenType: core.screenType)
        var tubeFilter: ResolvedShader?
        if let bezel, bezel.presetID == nil {
            if let selected, !TVBezelShader.isBezelFilter(selected.entry) {
                if bezel.image == nil {
                    let values = selected.values.merging(TVBezelShader.curvatureOffValues(for: selected.entry)) { _, off in off }
                    tubeFilter = ResolvedShader(entry: selected.entry, values: values, revision: selected.revision)
                } else {
                    tubeFilter = selected
                }
            } else if let look = bezel.look, let entry = ShaderCatalog.shared.entry(for: look.shaderID) {
                let values = look.values.merging(TVBezelShader.curvatureOffValues(for: entry)) { _, off in off }
                tubeFilter = ResolvedShader(entry: entry, values: values, revision: bezel.id.hashValue)
            }
        }
        renderer.updateLocalBezel(bezel, filter: tubeFilter, lightsRoom: Defaults[.externalDisplayBezelLightsRoom],
                                  flatGlass: tubeFilter.map { TVBezelShader.bendsPictureItself($0.entry) } ?? false)

        guard canShowGameplayBezels, gameBezels, pinned == nil, let context = gameplayBezelGame else { return }
        let style = Defaults[.externalDisplayBezelProjectStyle]
        guard artwork.begin(game: context.md5, style: style) else { return }
        Task { @MainActor [weak self] in
            let downloaded = await BezelProjectService.shared.artwork(for: context, style: style)
            guard let downloaded, artwork.finish(game: context.md5, style: style, bezelID: downloaded.id) else { return }
            self?.updateGameplayBezel()
            #if os(iOS)
            self?.updateExternalDisplay()
            #endif
        }
    }
}

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
