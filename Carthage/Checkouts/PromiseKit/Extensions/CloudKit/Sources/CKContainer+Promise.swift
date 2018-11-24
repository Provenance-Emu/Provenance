import CloudKit
#if !PMKCocoaPods
import PromiseKit
#endif

#if swift(>=4.2)
#else
public extension CKRecord {
    typealias ID = CKRecordID
}
public typealias CKContainer_Application_Permissions = CKApplicationPermissions
public typealias CKContainer_Application_PermissionStatus = CKApplicationPermissionStatus
#endif

/**
 To import the `CKContainer` category:

    use_frameworks!
    pod "PromiseKit/CloudKit"
 
 And then in your sources:

    @import PromiseKit;
*/
extension CKContainer {
    /// Reports whether the current user’s iCloud account can be accessed.
    public func accountStatus() -> Promise<CKAccountStatus> {
        return Promise { accountStatus(completionHandler: $0.resolve) }
    }

    /// Requests the specified permission from the user asynchronously.
    public func requestApplicationPermission(_ applicationPermissions: CKContainer_Application_Permissions) -> Promise<CKContainer_Application_PermissionStatus> {
        return Promise { requestApplicationPermission(applicationPermissions, completionHandler: $0.resolve) }
    }

    /// Checks the status of the specified permission asynchronously.
    public func status(forApplicationPermission applicationPermissions: CKContainer_Application_Permissions) -> Promise<CKContainer_Application_PermissionStatus> {
        return Promise { status(forApplicationPermission: applicationPermissions, completionHandler: $0.resolve) }
    }

#if !os(tvOS)
    /// Retrieves information about all discoverable users that are known to the current user.
    @available(*, deprecated)
    public func discoverAllContactUserInfos() -> Promise<[CKUserIdentity]> {
        return Promise { discoverAllIdentities(completionHandler: $0.resolve) }
    }

    public func discoverAllIdentities() -> Promise<[CKUserIdentity]> {
        return Promise { discoverAllIdentities(completionHandler: $0.resolve) }
    }
#endif

    /// Retrieves information about a single user based on that user’s email address.
    @available(*, deprecated)
    public func discoverUserInfo(withEmailAddress email: String) -> Promise<CKUserIdentity> {
        return Promise { discoverUserIdentity(withEmailAddress: email, completionHandler: $0.resolve) }
    }

    /// Retrieves information about a single user based on that user’s email address.
    public func discoverUserIdentity(withEmailAddress email: String) -> Promise<CKUserIdentity> {
        return Promise { discoverUserIdentity(withEmailAddress: email, completionHandler: $0.resolve) }
    }

    /// Retrieves information about a single user based on the ID of the corresponding user record.
    @available(*, deprecated)
    public func discoverUserInfo(withUserRecordID recordID: CKRecord.ID) -> Promise<CKUserIdentity> {
        return Promise { discoverUserIdentity(withUserRecordID: recordID, completionHandler: $0.resolve) }
    }

    /// Retrieves information about a single user based on the ID of the corresponding user record.
    public func discoverUserIdentity(withUserRecordID recordID: CKRecord.ID) -> Promise<CKUserIdentity> {
        return Promise { discoverUserIdentity(withUserRecordID: recordID, completionHandler: $0.resolve) }
    }

    /// Returns the user record ID associated with the current user.
    public func fetchUserRecordID() -> Promise<CKRecord.ID> {
        return Promise { fetchUserRecordID(completionHandler: $0.resolve) }
    }
}
