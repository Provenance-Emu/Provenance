//
//  UISearchController+Rx.swift
//  ProvenanceTV
//
//  Created by Dan Berglund on 2020-06-03.
//  Copyright © 2020 Provenance Emu. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

private class RxUISearchResultsUpdating: DelegateProxy<UISearchController, UISearchResultsUpdating>, DelegateProxyType, UISearchResultsUpdating {
    static func registerKnownImplementations() {
        self.register(make: { RxUISearchResultsUpdating.init(parentObject: $0, delegateProxy: RxUISearchResultsUpdating.self) })
    }

    static func currentDelegate(for object: UISearchController) -> UISearchResultsUpdating? {
        return object.searchResultsUpdater
    }

    static func setCurrentDelegate(_ delegate: UISearchResultsUpdating?, to object: UISearchController) {
        object.searchResultsUpdater = delegate
    }

    fileprivate var updates = PublishSubject<UISearchController>()
    func updateSearchResults(for searchController: UISearchController) {
        updates.onNext(searchController)
    }
}

extension Reactive where Base: UISearchController {
    private var searchResultsUpdating: RxUISearchResultsUpdating {
        RxUISearchResultsUpdating.proxy(for: base)
    }
    var searchText: Observable<String> {
        searchResultsUpdating.updates
            .compactMap { $0.searchBar.text }
    }
}
