import Foundation
import PVPrimitives
import SwiftUI

public protocol CheatEntry: Identifiable, Hashable {
    var id: String { get }
    var code: String { get }
    var type: CheatCodeTypes { get }
    var title: String { get }
    var enabled: Bool { get }

    init(id: String, code: String, type: CheatCodeTypes, title: String, enabled: Bool)
}

public protocol CheatDriver: ObservableObject {
    associatedtype Entry: CheatEntry

    /// Published property to track cheats
    var cheats: [Entry] { get }
    /// The game title associated with this driver
    var gameTitle: String { get }
    /// The supported cheat code types for this game/core combination
    var supportedCheatTypes: [CheatCodeTypes] { get }

    func addCheat(_ cheat: Entry)
    func toggleCheat(_ id: String)
    func deleteCheat(_ id: String)
    func updateCheat(_ cheat: Entry)
}
