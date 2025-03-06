import Foundation
import RealmSwift

public struct DiscSelectionAlert {
    @ThreadSafe
    public var game: PVGame?
    public let discs: [Disc]
    public let title: String = "Select Disc"
    public let message: String = "Choose which disc to load"
    
    public init(game: PVGame, discs: [Disc]) {
        self.game = game
        self.discs = discs
    }

    public struct Disc: Identifiable {
        public let id = UUID()
        public let fileName: String
        public let path: String
        
        public init(fileName: String, path: String) {
            self.fileName = fileName
            self.path = path
        }
    }
}
