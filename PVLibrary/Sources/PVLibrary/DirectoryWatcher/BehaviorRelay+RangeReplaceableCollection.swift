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
        var array = self.value
        array.append(element)
        self.accept(array)
    }
}

public extension BehaviorRelay where Element: SetAlgebra {

    func insert(_ element: Element.Element) -> (inserted: Bool, memberAfterInsert: Element.Element) {
        var set = self.value
        let inserted = set.insert(element)
        self.accept(set)
        return inserted
    }

    func remove(_ element: Element.Element) -> Element.Element? {
        var set = self.value
        let removed = set.remove(element)
        self.accept(set)
        return removed
    }
}
