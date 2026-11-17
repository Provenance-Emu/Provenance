import Foundation
import PVLogging
import PVLibrary
import PVRealm
import PVUIBase

public extension Array<URLQueryItem> {
    subscript(key: String) -> String? {
        get {
            return first(where: {$0.name == key})?.value
        }
        set(newValue) {

            if let newValue = newValue {
                removeAll(where: {$0.name == key})
                let newItem = URLQueryItem(name: key, value: newValue)
                append(newItem)
            } else {
                removeAll(where: {$0.name == key})
            }
        }
    }
}

extension PVApplicationServices {
    @MainActor
    internal func fetchGame(byMD5 md5: String) -> PVGame? {
        let realm = RomDatabase.sharedInstance.realm
        return realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased())
    }

    /// Ecosystem callbacks: a sibling app waking us after leaving a game in the
    /// shared drop box (`provenance://handoff?id=…&from=…`), or a queried app
    /// answering with its game list (`provenance://<source>?games=…`). Returns
    /// false when the URL is neither, so the caller's invalid-host path still logs.
    public func handleEcosystemCallback(_ url: URL) -> Bool {
        if EcosystemHandoff.isWakeURL(url) {
            let from = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?["from"] ?? "unknown"
            ILOG("Ecosystem: hand-off wake-up from \(from)://")
            EcosystemHandoffReceiver.shared.receivePending()
            return true
        }
        if let (source, games) = EcosystemCallbackParser.parse(url: url) {
            ILOG("Ecosystem: received \(games.count) games from \(source.displayName)")
            NotificationCenter.default.post(
                name: .ecosystemGamesReceived,
                object: nil,
                userInfo: ["source": source.rawValue, "games": games]
            )
            return true
        }
        return false
    }

}
