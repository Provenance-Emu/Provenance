//
//  Array+Extensions.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 11/26/16.
//  Copyright © 2016 kzaher. All rights reserved.
//

import Foundation


extension Dictionary {
    init<T>(elements: [T], keySelector: (T) -> Key, valueSelector: (T) -> Value) {
        var result: [Key: Value] = [:]
        for element in elements {
            result[keySelector(element)] = valueSelector(element)
        }

        self = result
    }
}
