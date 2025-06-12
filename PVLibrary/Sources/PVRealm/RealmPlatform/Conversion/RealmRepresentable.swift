import Foundation
import PVPrimitives

public protocol RealmRepresentable {
    associatedtype RealmType: DomainConvertibleType

    var uid: String { get }

    func asRealm() -> RealmType
}
