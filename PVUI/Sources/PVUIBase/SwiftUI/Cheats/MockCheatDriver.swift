import Foundation
import SwiftUI
import Combine
import PVPrimitives

/// Mock driver for testing cheat code management
public class MockCheatDriver: CheatDriver {
    public typealias Entry = MockCheatEntry

    // Shared instances for different mock scenarios
    private static var sharedMockInstance: MockCheatDriver?
    private static var sharedEmptyInstance: MockCheatDriver?

    public static func shared(mockData: Bool = true) -> MockCheatDriver {
        if mockData {
            if sharedMockInstance == nil {
                sharedMockInstance = MockCheatDriver(mockData: true)
            }
            return sharedMockInstance!
        } else {
            if sharedEmptyInstance == nil {
                sharedEmptyInstance = MockCheatDriver(mockData: false)
            }
            return sharedEmptyInstance!
        }
    }

    @Published private(set) public var cheats: [MockCheatEntry] = []
    public let gameTitle: String
    public let supportedCheatTypes: [CheatCodeTypes]

    public struct MockCheatEntry: CheatEntry {
        public let id: String
        public var code: String
        public var type: CheatCodeTypes
        public var title: String
        public var enabled: Bool

        public init(id: String, code: String, type: CheatCodeTypes, title: String, enabled: Bool) {
            self.id = id
            self.code = code
            self.type = type
            self.title = title
            self.enabled = enabled
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    // Make init private to enforce singleton usage
    private init(mockData: Bool = true,
                gameTitle: String = "Super Mario World",
                supportedTypes: [CheatCodeTypes] = [.gameGenie, .gameShark]) {
        self.gameTitle = gameTitle
        self.supportedCheatTypes = supportedTypes
        if mockData {
            loadMockData()
        }
    }

    private func loadMockData() {
        cheats = [
            MockCheatEntry(
                id: UUID().uuidString,
                code: "01AB2345",
                type: .gameShark,
                title: "Infinite Lives",
                enabled: true
            ),
            MockCheatEntry(
                id: UUID().uuidString,
                code: "ABCD-EFGH",
                type: .gameGenie,
                title: "Max Power",
                enabled: false
            )
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
