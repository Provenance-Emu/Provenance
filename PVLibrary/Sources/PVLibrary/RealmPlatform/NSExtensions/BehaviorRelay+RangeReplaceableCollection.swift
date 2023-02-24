//
//  BehaviorRelay+RangeReplaceableCollection.swift
//  BehaviorRelay+RangeReplaceableCollection
//
//  Created by Joseph Mattiello on 9/5/21.
//  Copyright © 2021 Provenance Emu. All rights reserved.
//

import Foundation
import RxCocoa

public extension BehaviorRelay where Element: RangeReplaceableCollection {
    func add(element: Element.Element) {
        var array = value
        array.append(element)
        accept(array)
    }
}

public extension BehaviorRelay where Element: SetAlgebra {
    func insert(_ element: Element.Element) -> (inserted: Bool, memberAfterInsert: Element.Element) {
        var set = value
        let inserted = set.insert(element)
        accept(set)
        return inserted
    }

    func remove(_ element: Element.Element) -> Element.Element? {
        var set = value
        let removed = set.remove(element)
        accept(set)
        return removed
    }
}
