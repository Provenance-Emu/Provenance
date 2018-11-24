import PMKAccounts
import PromiseKit
import Accounts
import XCTest

class Test_ACAccountStore_Swift: XCTestCase {
    var dummy: ACAccount { return ACAccount() }

    func test_renewCredentialsForAccount() {
        let ex = expectation(description: "")

        class MockAccountStore: ACAccountStore {
            override func renewCredentials(for account: ACAccount!, completion: ACAccountStoreCredentialRenewalHandler!) {
                completion(.renewed, nil)
            }
        }

        MockAccountStore().renewCredentials(for: dummy).done { result in
            XCTAssertEqual(result, ACAccountCredentialRenewResult.renewed)
            ex.fulfill()
        }.catch {
            XCTFail("\($0)")
        }

        waitForExpectations(timeout: 1)
    }

    func test_requestAccessToAccountsWithType() {
        class MockAccountStore: ACAccountStore {
            override func requestAccessToAccounts(with accountType: ACAccountType!, options: [AnyHashable : Any]! = [:], completion: ACAccountStoreRequestAccessCompletionHandler!) {
                completion(true, nil)
            }
        }

        let ex = expectation(description: "")
        let store = MockAccountStore()
        let type = store.accountType(withAccountTypeIdentifier: ACAccountTypeIdentifierFacebook)!
        store.requestAccessToAccounts(with: type).done { _ in
            ex.fulfill()
        }.catch {
            XCTFail("\($0)")
        }

        waitForExpectations(timeout: 1)
    }

    func test_saveAccount() {
        class MockAccountStore: ACAccountStore {
            override func saveAccount(_ account: ACAccount!, withCompletionHandler completionHandler: ACAccountStoreSaveCompletionHandler!) {
                completionHandler(true, nil)
            }
        }

        let ex = expectation(description: "")
        MockAccountStore().saveAccount(dummy).done { _ in
            ex.fulfill()
        }.catch {
            XCTFail("\($0)")
        }

        waitForExpectations(timeout: 1)
    }

    func test_removeAccount() {
        class MockAccountStore: ACAccountStore {
            override func removeAccount(_ account: ACAccount!, withCompletionHandler completionHandler: ACAccountStoreSaveCompletionHandler!) {
                completionHandler(true, nil)
            }
        }

        let ex = expectation(description: "")
        MockAccountStore().removeAccount(dummy).done { _ in
            ex.fulfill()
        }.catch {
            XCTFail("\($0)")
        }

        waitForExpectations(timeout: 1)
    }
}
