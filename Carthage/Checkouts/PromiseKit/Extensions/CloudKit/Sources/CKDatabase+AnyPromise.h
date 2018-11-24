#import <CloudKit/CKDatabase.h>
#import <PromiseKit/AnyPromise.h>

/**
 To import the `CKDatabase` category:

    use_frameworks!
    pod "PromiseKit/CloudKit"
 
 And then in your sources:

    @import PromiseKit;
*/
@interface CKDatabase (PromiseKit)

/// Fetches one record asynchronously from the current database.
- (AnyPromise *)fetchRecordWithID:(CKRecordID *)recordID NS_REFINED_FOR_SWIFT;
/// Saves one record zone asynchronously to the current database.
- (AnyPromise *)saveRecord:(CKRecord *)record NS_REFINED_FOR_SWIFT;
/// Delete one subscription object asynchronously from the current database.
- (AnyPromise *)deleteRecordWithID:(CKRecordID *)recordID NS_REFINED_FOR_SWIFT;

/// Searches the specified zone asynchronously for records that match the query parameters.
- (AnyPromise *)performQuery:(CKQuery *)query inZoneWithID:(CKRecordZoneID *)zoneID NS_REFINED_FOR_SWIFT;

/// Fetches all record zones asynchronously from the current database.
- (AnyPromise *)fetchAllRecordZones NS_REFINED_FOR_SWIFT;
/// Fetches one record asynchronously from the current database.
- (AnyPromise *)fetchRecordZoneWithID:(CKRecordZoneID *)zoneID NS_REFINED_FOR_SWIFT;
/// Saves one record zone asynchronously to the current database.
- (AnyPromise *)saveRecordZone:(CKRecordZone *)zone NS_REFINED_FOR_SWIFT;
/// Delete one subscription object asynchronously from the current database.
- (AnyPromise *)deleteRecordZoneWithID:(CKRecordZoneID *)zoneID NS_REFINED_FOR_SWIFT;

#if !(TARGET_OS_WATCH && (TARGET_OS_EMBEDDED || TARGET_OS_SIMULATOR))
/// Fetches one record asynchronously from the current database.
- (AnyPromise *)fetchSubscriptionWithID:(NSString *)subscriptionID NS_REFINED_FOR_SWIFT;
/// Fetches all subscription objects asynchronously from the current database.
- (AnyPromise *)fetchAllSubscriptions NS_REFINED_FOR_SWIFT;
/// Saves one subscription object asynchronously to the current database.
- (AnyPromise *)saveSubscription:(CKSubscription *)subscription NS_REFINED_FOR_SWIFT;
/// Delete one subscription object asynchronously from the current database.
- (AnyPromise *)deleteSubscriptionWithID:(NSString *)subscriptionID NS_REFINED_FOR_SWIFT;
#endif

@end
