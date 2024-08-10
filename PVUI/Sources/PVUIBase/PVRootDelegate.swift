// MARK: - PVRootDelegate

public protocol PVRootDelegate: AnyObject {
    func attemptToDelete(game: PVGame)
    func showUnderConstructionAlert()
    // objects fetched via @ObservedResults are `frozen`, so we need to thaw them before Realm lets us use them
    // the following methods call their equivalent GameLaunchingViewController methods with thawed objects
    func root_canLoad(_ game: PVGame) async throws
    func root_load(_ game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async
    func root_openSaveState(_ saveState: PVSaveState)
    func root_updateRecentGames(_ game: PVGame)
    func root_presentCoreSelection(forGame game: PVGame, sender: Any?)
}