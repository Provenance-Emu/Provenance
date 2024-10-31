//
//  RxRealm extensions
//
//  Copyright (c) 2016 RxSwiftCommunity. All rights reserved.
//  Check the LICENSE file for details
//

import Foundation

import RealmSwift
import RxCocoa
import RxRealm
import RxSwift

public class RealmBindObserver<O: Object, C: RealmCollection, DS>: ObserverType {
    typealias BindingType = (DS, C, RealmChangeset?) -> Void
    public typealias E = (C, RealmChangeset?)

    let dataSource: DS
    let binding: BindingType

    init(dataSource: DS, binding: @escaping BindingType) {
        self.dataSource = dataSource
        self.binding = binding
    }

    public func on(_ event: Event<E>) {
        switch event {
        case let .next(element):
            binding(dataSource, element.0, element.1)
        case .error:
            return
        case .completed:
            return
        }
    }

    func asObserver() -> AnyObserver<E> {
        return AnyObserver(eventHandler: on)
    }
}
