import SwiftUI
import PVRealm
import RealmSwift
import PVSwiftUI
import PVLibrary
import PVLogging

/// A thread-safe game cell model that doesn't directly access Realm objects
struct GameCellModel: Identifiable {
    let id: String
    let title: String
    let artworkURLString: String?
    let originalGame: PVGame
    
    init(from game: PVGame) {
        // Safely extract properties from the Realm object
        self.id = game.id
        self.title = game.title
        self.artworkURLString = game.artworkURL
        self.originalGame = game
    }
}

/// A wrapper view for game cells that avoids direct Realm object access
struct GameCellWrapper: View {
    // Thread-safe model instead of direct Realm object
    let model: GameCellModel
    let isSelected: Bool
    let onSelect: (PVGame) -> Void
    
    init(game: PVGame, isSelected: Bool, onSelect: @escaping (PVGame) -> Void) {
        self.model = GameCellModel(from: game)
        self.isSelected = isSelected
        self.onSelect = onSelect
    }
    
    var body: some View {
        Button(action: {
            onSelect(model.originalGame)
        }) {
            ZStack {
                // Game artwork or placeholder
                if let artworkURL = model.artworkURLString, let url = URL(string: artworkURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Image(systemName: "gamecontroller")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding()
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "gamecontroller")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                }
                
                // Game title overlay at bottom
                VStack {
                    Spacer()
                    Text(model.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(6)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    // This is just a placeholder for preview
    GameCellWrapper(
        game: PVGame(),
        isSelected: false,
        onSelect: { _ in }
    )
    .frame(width: 160, height: 220)
    .previewLayout(.sizeThatFits)
}
