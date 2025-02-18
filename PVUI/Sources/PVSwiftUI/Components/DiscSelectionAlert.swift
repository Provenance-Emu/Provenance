import Foundation

struct DiscSelectionAlert {
    let game: PVGame
    let discs: [Disc]
    let title: String = "Select Disc"
    let message: String = "Choose which disc to load"

    struct Disc: Identifiable {
        let id = UUID()
        let fileName: String
        let path: String
    }
}
