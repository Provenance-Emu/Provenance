import Foundation
import PVUIObjC

/// Presents a library game's netplay details without passing a thread-confined Realm object.
public struct NetplayLibraryRequest: Identifiable {
    public static let notification: Notification.Name = .pvOpenNetplayLibraryGame
    public let gameMD5: String
    public var id: String { gameMD5 }
    public init(gameMD5: String) { self.gameMD5 = gameMD5 }
}

public extension Notification.Name {
    static let pvOpenNetplayLibraryGame = Notification.Name.PVOpenNetplayLibraryGame
}
