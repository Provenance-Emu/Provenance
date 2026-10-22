import Foundation
import PVCoreBridge

@objc(IdentityTestProvider) final class IdentityTestProvider: NSObject, PVLibraryDiscIdentityReading {
    override init() { fatalError("Dispatch must never instantiate a core") }
    static func libraryIdentity(atPath path: String) -> [String: Any]? {
        path == "/disc two.rvz" ? ["gameID": "GTEST1", "discNumber": 1, "revision": 7] : nil
    }
}
@objc(IdentityUnsupportedCore) final class IdentityUnsupportedCore: NSObject {}
let url = URL(fileURLWithPath: "/disc two.rvz")
let result = CoreLoader.readLibraryDiscIdentity(at: url, coreClassName: "IdentityTestProvider")
precondition(result?["gameID"] as? String == "GTEST1")
precondition(result?["discNumber"] as? Int == 1)
precondition(result?["revision"] as? Int == 7)
precondition(CoreLoader.readLibraryDiscIdentity(at: URL(fileURLWithPath: "/bad"), coreClassName: "IdentityTestProvider") == nil)
precondition(CoreLoader.readLibraryDiscIdentity(at: url, coreClassName: "MissingCoreClass") == nil)
precondition(CoreLoader.readLibraryDiscIdentity(at: url, coreClassName: "IdentityUnsupportedCore") == nil)
precondition(CoreLoader.readLibraryDiscIdentity(at: URL(string: "https://example.com/disc")!, coreClassName: "IdentityTestProvider") == nil)
print("Typed identity dispatch passed")
