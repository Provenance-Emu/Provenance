import Foundation
import SwiftUI
import Combine
import PVPrimitives

/// Mock driver for testing cheat code management
public class MockCheatDriver: CheatDriver {
    public typealias Entry = MockCheatEntry

    @Published private(set) public var cheats: [MockCheatEntry] = []

    public struct MockCheatEntry: CheatEntry {
        public let id: String
        public var code: String
        public var type: CheatCodeTypes
        public var title: String
        public var enabled: Bool
        public var gameTitle: String

        public init(id: String, code: String, type: CheatCodeTypes, title: String, enabled: Bool, gameTitle: String) {
            self.id = id
            self.code = code
            self.type = type
            self.title = title
            self.enabled = enabled
            self.gameTitle = gameTitle
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    public init(mockData: Bool = true) {
        if mockData {
            loadMockData()
        }
    }

    private func loadMockData() {
        cheats = [
            MockCheatEntry(id: UUID().uuidString,
                          code: "01AB2345",
                          type: .gameShark,
                          title: "Infinite Lives",
                          enabled: true,
                          gameTitle: "Super Mario World"),
            MockCheatEntry(id: UUID().uuidString,
                          code: "ABCD-EFGH",
                          type: .gameGenie,
                          title: "Max Power",
                          enabled: false,
                          gameTitle: "Sonic the Hedgehog")
        ]
    }

    public func addCheat(_ cheat: MockCheatEntry) {
        cheats.append(cheat)
    }

    public func toggleCheat(_ id: String) {
        if let index = cheats.firstIndex(where: { $0.id == id }) {
            var updatedCheat = cheats[index]
            updatedCheat.enabled.toggle()
            cheats[index] = updatedCheat
        }
    }

    public func deleteCheat(_ id: String) {
        cheats.removeAll { $0.id == id }
    }

    public func updateCheat(_ cheat: MockCheatEntry) {
        if let index = cheats.firstIndex(where: { $0.id == cheat.id }) {
            cheats[index] = cheat
        }
    }
}
