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

    /// Ecosystem callbacks: a queried app answering with its game list
    /// (`provenance://<source>?games=…`) or a user-approved ROM transfer offer
    /// (`provenance://<source>?fetch=…`). Returns false when the URL is
    /// neither, so the caller's invalid-host path still logs.
    public func handleEcosystemCallback(_ url: URL) -> Bool {
        if let (source, games) = EcosystemCallbackParser.parse(url: url) {
            ILOG("Ecosystem: received \(games.count) games from \(source.displayName)")
            NotificationCenter.default.post(
                name: .ecosystemGamesReceived,
                object: nil,
                userInfo: ["source": source.rawValue, "games": games]
            )
            return true
        }
        if let (source, payload) = EcosystemFetchParser.parse(url: url) {
            ILOG("Ecosystem: fetch offer from \(source.displayName) for '\(payload.name)'")
            Task {
                do {
                    let container = try await EcosystemFetchService.shared.download(payload, from: source)
                    NotificationCenter.default.post(
                        name: .ecosystemFetchCompleted,
                        object: nil,
                        userInfo: [
                            "source": source.rawValue,
                            "name": payload.name,
                            "path": container.path
                        ]
                    )
                } catch {
                    ELOG("Ecosystem: fetch of '\(payload.name)' failed: \(error)")
                    NotificationCenter.default.post(
                        name: .ecosystemFetchFailed,
                        object: nil,
                        userInfo: ["source": source.rawValue, "name": payload.name, "error": "\(error)"]
                    )
                }
            }
            return true
        }
        return false
    }

}
