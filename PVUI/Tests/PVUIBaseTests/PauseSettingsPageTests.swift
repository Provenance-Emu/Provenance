import Testing
@testable import PVUIBase

@Suite("Pause menu Settings page")
struct PauseSettingsPageTests {
    @Test("Auto load wins over asking, as the launcher reads them")
    func modeFromSwitches() {
        #expect(PauseLaunchSaveMode(autoLoad: true, ask: true) == .resume)
        #expect(PauseLaunchSaveMode(autoLoad: true, ask: false) == .resume)
        #expect(PauseLaunchSaveMode(autoLoad: false, ask: true) == .ask)
        #expect(PauseLaunchSaveMode(autoLoad: false, ask: false) == .off)
    }

    @Test("Each mode stores switches that read back as itself", arguments: PauseLaunchSaveMode.allCases)
    func roundTrip(mode: PauseLaunchSaveMode) {
        let switches = mode.switches
        #expect(PauseLaunchSaveMode(autoLoad: switches.autoLoad, ask: switches.ask) == mode)
    }

    @Test("A tap visits every mode and comes back")
    func cycle() {
        var mode = PauseLaunchSaveMode.resume
        var seen: [PauseLaunchSaveMode] = []
        for _ in PauseLaunchSaveMode.allCases {
            seen.append(mode)
            mode = mode.next
        }
        #expect(mode == .resume)
        #expect(Set(seen) == Set(PauseLaunchSaveMode.allCases))
    }

    @Test("Every switch cell maps to a setting, and the launch cell offers each mode")
    func cells() {
        let cells = PauseTileMenuViewModel.preferenceCells()
        let switchIDs = cells.map(\.id).filter { $0 != PauseTileMenuViewModel.launchSaveTileID }
        #expect(!switchIDs.isEmpty)
        for id in switchIDs {
            #expect(PauseTileMenuViewModel.preferenceKey(forCellID: id) != nil, "\(id) has no setting")
        }
        let launch = PauseTileMenuViewModel.launchSaveCell(mode: .ask)
        #expect(launch.longPressOptions?.count == PauseLaunchSaveMode.allCases.count)
        #expect(launch.longPressOptions?.filter(\.isSelected).map(\.id)
                == [PauseTileMenuViewModel.launchSaveOptionPrefix + "ask"])
    }
}
