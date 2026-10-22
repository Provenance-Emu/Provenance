import Foundation
import PVCoreBridge

extension CoreLoader {
    /// Reads identity using the plist's principal class without creating a core.
    /// Missing classes, unsupported providers and unresolved files remain nil.
    public static func readLibraryDiscIdentity(at url: URL, coreClassName: String) -> [String: Any]? {
        guard url.isFileURL,
              let reader = NSClassFromString(coreClassName) as? PVLibraryDiscIdentityReading.Type else {
            return nil
        }
        return reader.libraryIdentity(atPath: url.path)
    }
}
