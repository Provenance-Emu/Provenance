import Testing
@testable import PVSettings

@Suite(.serialized)
struct CloudSyncContentPolicyTests {
    @Test func freeScopeProtectsProgressWithoutChangingRequestedScope() {
        CloudSyncContentAccess.updateOwnership(isTV: false, isAppStore: true, isSettled: true, hasPlus: false)
        let requested = CloudKitSyncContentType.all
        let effective = CloudSyncContentAccess.effectiveScope(for: requested)
        #expect(effective == .metadataOnly)
        #expect(effective.includesSaveProgress)
        #expect(!effective.allowsAutomaticROMFileTransfers)
        #expect(requested == .all)
        CloudSyncContentAccess.updateOwnership(isTV: false, isAppStore: true, isSettled: true, hasPlus: true)
        #expect(CloudSyncContentAccess.effectiveScope(for: requested) == requested)
    }

    @Test func onlyExplicitROMLibraryScopesAllowAutomaticPayloads() {
        for scope in CloudKitSyncContentType.allCases {
            #expect(scope.allowsAutomaticROMFileTransfers == (scope == .all || scope == .romsOnly))
            #expect(scope.includesSaveProgress == (scope != .romsOnly))
        }
    }

    @Test func pendingOwnershipPausesROMTransfersAndKeepsSaveProtection() {
        CloudSyncContentAccess.updateOwnership(isTV: false, isAppStore: true, isSettled: false, hasPlus: false)
        for requested in CloudKitSyncContentType.allCases {
            let effective = CloudSyncContentAccess.effectiveScope(for: requested)
            #expect(effective.includesSaveProgress)
            #expect(!effective.allowsAutomaticROMFileTransfers)
        }
    }

    @Test func freeTVAndNonStoreBaselinePreservesEveryExistingScope() {
        for requested in CloudKitSyncContentType.allCases {
            CloudSyncContentAccess.updateOwnership(isTV: true, isAppStore: true, isSettled: false, hasPlus: false)
            #expect(CloudSyncContentAccess.effectiveScope(for: requested) == requested)
            CloudSyncContentAccess.updateOwnership(isTV: false, isAppStore: false, isSettled: true, hasPlus: false)
            #expect(CloudSyncContentAccess.effectiveScope(for: requested) == requested)
        }
    }
}
