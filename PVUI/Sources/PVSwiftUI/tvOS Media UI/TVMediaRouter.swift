import SwiftUI
import PVLibrary

#if os(tvOS) || os(iOS)

/// Protocol for experiences that can be presented in the tvOS Media UI
@available(tvOS 16.0, *)
protocol TVMediaExperience: Identifiable {
    associatedtype Content: View

    var id: String { get }
    var title: String { get }

    /// Whether this experience supports back navigation
    var canNavigateBack: Bool { get }

    /// Build the experience view
    @ViewBuilder func makeBody(router: TVMediaRouter) -> Content
}

/// Default implementation
@available(tvOS 16.0, *)
extension TVMediaExperience {
    var canNavigateBack: Bool { true }
}

/// Centralized routing for the tvOS Media UI
@available(tvOS 16.0, *)
@MainActor
final class TVMediaRouter: ObservableObject {

    /// Navigation stack for experiences
    @Published private(set) var navigationPath: [AnyHashable] = []

    /// Current destination from sidebar
    @Published var destination: TVMediaDestination = .home

    /// Selected system identifier
    @Published var selectedSystemID: String = ""

    /// System IDs to filter saves by (empty = show all)
    @Published var saveSystemFilter: Set<String> = []

    /// Active modal presentation
    @Published var activeModal: TVMediaModal?

    /// Remembers where `.systemGames` was entered from so Back can return appropriately.
    @Published private(set) var systemGamesReturnDestination: TVMediaDestination?

    /// Remembers where `.saves` (filtered by system) was entered from so Back can return appropriately.
    @Published private(set) var savesReturnDestination: TVMediaDestination?

    /// Whether back navigation is possible
    var canGoBack: Bool {
        !navigationPath.isEmpty
    }

    /// Navigate to a destination (resets nav stack)
    func navigate(to dest: TVMediaDestination) {
        destination = dest
        navigationPath = []
        systemGamesReturnDestination = nil
        savesReturnDestination = nil

        // Reset saves filter when navigating from sidebar
        if dest == .saves {
            saveSystemFilter = []
        }
    }

    /// Navigate to a system's games
    func navigateToSystem(_ systemID: String) {
        systemGamesReturnDestination = destination
        selectedSystemID = systemID
        destination = .systemGames
        navigationPath = []
    }

    /// Navigate back from `.systemGames` to the destination it was entered from.
    @discardableResult
    func navigateBackFromSystemGames() -> Bool {
        guard destination == .systemGames else { return false }
        guard let returnDestination = systemGamesReturnDestination else { return false }
        destination = returnDestination
        navigationPath = []
        systemGamesReturnDestination = nil
        return true
    }

    /// Navigate to saves with optional system filter
    func navigateToSaves(filterBySystem systemID: String? = nil) {
        if let systemID {
            savesReturnDestination = destination
            saveSystemFilter = [systemID]
        } else {
            savesReturnDestination = nil
            saveSystemFilter = []
        }
        destination = .saves
        navigationPath = []
    }

    /// Push onto navigation stack
    func push(_ item: AnyHashable) {
        navigationPath.append(item)
    }

    /// Pop from navigation stack
    func pop() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    /// Pop to root of current destination
    func popToRoot() {
        navigationPath = []
    }

    /// Present a modal
    func present(_ modal: TVMediaModal) {
        activeModal = modal
    }

    /// Dismiss active modal
    func dismissModal() {
        activeModal = nil
    }

    /// Handle back navigation request
    func handleBack() -> Bool {
        if activeModal != nil {
            dismissModal()
            return true
        }

        if navigateBackFromSystemGames() {
            return true
        }

        if destination == .saves, let returnDestination = savesReturnDestination {
            destination = returnDestination
            navigationPath = []
            saveSystemFilter = []
            savesReturnDestination = nil
            return true
        }

        if canGoBack {
            pop()
            return true
        }

        return false
    }
}

/// Modal presentations for the tvOS Media UI
@available(tvOS 16.0, *)
enum TVMediaModal: Identifiable, Equatable {
    case saveBrowser(systemID: String, systemName: String, game: PVGame?)
    case systemPicker(game: PVGame)
    case renameGame(game: PVGame)
    case gameInfo(gameID: String)
    case importStatus
    case importQueue
    case freeROMs
    case romInstructions
    case artworkSearch(game: PVGame)
    case imagePicker(game: PVGame)

    var id: String {
        switch self {
        case .saveBrowser(let systemID, _, let game):
            return "saveBrowser-\(systemID)-\(game?.id ?? "all")"
        case .systemPicker(let game):
            return "systemPicker-\(game.id)"
        case .renameGame(let game):
            return "renameGame-\(game.id)"
        case .gameInfo(let gameID):
            return "gameInfo-\(gameID)"
        case .importStatus:
            return "importStatus"
        case .importQueue:
            return "importQueue"
        case .freeROMs:
            return "freeROMs"
        case .romInstructions:
            return "romInstructions"
        case .artworkSearch(let game):
            return "artworkSearch-\(game.id)"
        case .imagePicker(let game):
            return "imagePicker-\(game.id)"
        }
    }

    static func == (lhs: TVMediaModal, rhs: TVMediaModal) -> Bool {
        lhs.id == rhs.id
    }
}

/// Navigation path items
@available(tvOS 16.0, *)
enum TVMediaNavItem: Hashable {
    case allGames(systemID: String)
    case gameDetail(gameID: String)
}

#endif
