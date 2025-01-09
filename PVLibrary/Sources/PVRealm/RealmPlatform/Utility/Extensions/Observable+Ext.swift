import Foundation
import RxSwift
import AsyncAlgorithms
import PVPrimitives

public extension RxSwift.Observable where Element: Sequence, Element.Iterator.Element: DomainConvertibleType {
    typealias DomainType = Element.Iterator.Element.DomainType

    func mapToDomain() -> RxSwift.Observable<[DomainType]> {
        let values = self.values.map { $0.mapToDomain() }
        return values.asObservable()
    }
}

public extension Sequence where Iterator.Element: DomainConvertibleType {
    typealias Element = Iterator.Element
    func mapToDomain() -> [Element.DomainType] {
        return map {
            $0.asDomain()
        }
    }
}
