import CloudKit.CKDatabase
#if !PMKCocoaPods
import PromiseKit
#endif

#if swift(>=4.2)
#else
public extension CKRecordZone {
    typealias ID = CKRecordZoneID
}
#endif

/**
 To import the `CKDatabase` category:

    use_frameworks!
    pod "PromiseKit/CloudKit"
 
 And then in your sources:

    @import PromiseKit;
*/
extension CKDatabase {
    /// Fetches one record asynchronously from the current database.
    public func fetch(withRecordID recordID: CKRecord.ID) -> Promise<CKRecord> {
        return Promise { fetch(withRecordID: recordID, completionHandler: $0.resolve) }
    }

    /// Fetches one record zone asynchronously from the current database.
    public func fetch(withRecordZoneID recordZoneID: CKRecordZone.ID) -> Promise<CKRecordZone> {
        return Promise { fetch(withRecordZoneID: recordZoneID, completionHandler: $0.resolve) }
    }
    /// Fetches all record zones asynchronously from the current database.
    public func fetchAllRecordZones() -> Promise<[CKRecordZone]> {
        return Promise { fetchAllRecordZones(completionHandler: $0.resolve) }
    }

    /// Saves one record zone asynchronously to the current database.
    public func save(_ record: CKRecord) -> Promise<CKRecord> {
        return Promise { save(record, completionHandler: $0.resolve) }
    }

    /// Saves one record zone asynchronously to the current database.
    public func save(_ recordZone: CKRecordZone) -> Promise<CKRecordZone> {
        return Promise { save(recordZone, completionHandler: $0.resolve) }
    }

    /// Delete one subscription object asynchronously from the current database.
    public func delete(withRecordID recordID: CKRecord.ID) -> Promise<CKRecord.ID> {
        return Promise { delete(withRecordID: recordID, completionHandler: $0.resolve) }
    }

    /// Delete one subscription object asynchronously from the current database.
    public func delete(withRecordZoneID zoneID: CKRecordZone.ID) -> Promise<CKRecordZone.ID> {
        return Promise { delete(withRecordZoneID: zoneID, completionHandler: $0.resolve) }
    }

    /// Searches the specified zone asynchronously for records that match the query parameters.
    public func perform(_ query: CKQuery, inZoneWith zoneID: CKRecordZone.ID? = nil) -> Promise<[CKRecord]> {
        return Promise { perform(query, inZoneWith: zoneID, completionHandler: $0.resolve) }
    }

    /// Fetches the record for the current user.
    public func fetchUserRecord(_ container: CKContainer = CKContainer.default()) -> Promise<CKRecord> {
        return container.fetchUserRecordID().then(on: nil) { uid in
            return self.fetch(withRecordID: uid)
        }
    }

#if !os(watchOS)
    /// Fetches one record zone asynchronously from the current database.
    public func fetch(withSubscriptionID subscriptionID: String) -> Promise<CKSubscription> {
        return Promise { fetch(withSubscriptionID: subscriptionID, completionHandler: $0.resolve) }
    }

    /// Fetches all subscription objects asynchronously from the current database.
    public func fetchAllSubscriptions() -> Promise<[CKSubscription]> {
        return Promise { fetchAllSubscriptions(completionHandler: $0.resolve) }
    }

    /// Saves one subscription object asynchronously to the current database.
    public func save(_ subscription: CKSubscription) -> Promise<CKSubscription> {
        return Promise { save(subscription, completionHandler: $0.resolve) }
    }

    /// Delete one subscription object asynchronously from the current database.
    public func delete(withSubscriptionID subscriptionID: String) -> Promise<String> {
        return Promise { delete(withSubscriptionID: subscriptionID, completionHandler: $0.resolve) }
    }
#endif
}
