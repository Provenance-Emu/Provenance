import Foundation.NSError
import CoreFoundation
import AddressBook
#if !PMKCocoaPods
import PromiseKit
#endif

public enum AddressBookError: Error {
    case notDetermined
    case restricted
    case denied

    public var localizedDescription: String {
        switch self {
        case .notDetermined:
            return "Access to the address book could not be determined."
        case .restricted:
            return "A head of family must grant address book access."
        case .denied:
            return "Address book access has been denied."
        }
    }
}

/**
 Requests access to the address book.

 To import `ABAddressBookRequestAccess`:

    use_frameworks!
    pod "PromiseKit/AddressBook"

 And then in your sources:

    import PromiseKit

 @return A promise that fulfills with the ABAuthorizationStatus.
*/
public func ABAddressBookRequestAccess() -> Promise<ABAuthorizationStatus> {
    return ABAddressBookRequestAccess().map(on: nil) { (_, _) -> ABAuthorizationStatus in
        return ABAddressBookGetAuthorizationStatus()
    }
}

/**
 Requests access to the address book.

 To import `ABAddressBookRequestAccess`:

    pod "PromiseKit/AddressBook"

 And then in your sources:

    import PromiseKit

 @return A promise that fulfills with the ABAddressBook instance if access was granted.
*/
public func ABAddressBookRequestAccess() -> Promise<ABAddressBook> {
    return ABAddressBookRequestAccess().then(on: nil) { granted, book -> Promise<ABAddressBook> in
        guard granted else {
            switch ABAddressBookGetAuthorizationStatus() {
            case .notDetermined:
                throw AddressBookError.notDetermined
            case .restricted:
                throw AddressBookError.restricted
            case .denied:
                throw AddressBookError.denied
            case .authorized:
                fatalError("This should not happen")
            }
        }

        return .value(book)
    }
}

extension NSError {
    fileprivate convenience init(CFError error: CoreFoundation.CFError) {
        let domain = CFErrorGetDomain(error) as String
        let code = CFErrorGetCode(error)
        let info = CFErrorCopyUserInfo(error) as? [String: Any] ?? [:]
        self.init(domain: domain, code: code, userInfo: info)
    }
}

private func ABAddressBookRequestAccess() -> Promise<(Bool, ABAddressBook)> {
    var error: Unmanaged<CFError>? = nil
    guard let ubook = ABAddressBookCreateWithOptions(nil, &error) else {
        return Promise(error: NSError(CFError: error!.takeRetainedValue()))
    }

    let book: ABAddressBook = ubook.takeRetainedValue()
    return Promise { seal in
        ABAddressBookRequestAccessWithCompletion(book) { granted, error in
            if let error = error {
                seal.reject(NSError(CFError: error))
            } else {
                seal.fulfill((granted, book))
            }
        }
    }
}
