//
//  BindableResult.swift
//  Provenance
//
//  Created by Ian Clawson on 2/2/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import RealmSwift
#if canImport(SwiftUI)
import SwiftUI

@available(iOS 14, tvOS 14, *)
class BindableResults<Element>: ObservableObject where Element: RealmSwift.RealmCollectionValue {

    var results: Results<Element>
    private var token: NotificationToken!

    init(results: Results<Element>) {
        self.results = results
        lateInit()
    }

    func lateInit() {
        token = results.observe { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    deinit {
        token.invalidate()
    }
}
#endif
