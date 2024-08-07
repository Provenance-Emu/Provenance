import Foundation
import RxSwift
import AsyncAlgorithms

extension RxSwift.Observable where Element: Sequence, Element.Iterator.Element: DomainConvertibleType {
    typealias DomainType = Element.Iterator.Element.DomainType

    func mapToDomain() async -> RxSwift.Observable<[DomainType]> {
        let values = self.values.map { await $0.mapToDomain() }
        return values.asObservable()
    }
}

extension Sequence where Iterator.Element: DomainConvertibleType {
    typealias Element = Iterator.Element
    func mapToDomain() async -> [Element.DomainType] {
        return await asyncMap {
            await $0.asDomain()
        }
    }
}
