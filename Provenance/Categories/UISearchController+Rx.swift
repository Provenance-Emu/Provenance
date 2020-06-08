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

    fileprivate let updates = PublishSubject<UISearchController>()
    func updateSearchResults(for searchController: UISearchController) {
        updates.onNext(searchController)
    }
}

private class RxUISearchControllerDelegate: DelegateProxy<UISearchController, UISearchControllerDelegate>, DelegateProxyType, UISearchControllerDelegate {
    static func currentDelegate(for object: UISearchController) -> UISearchControllerDelegate? {
        return object.delegate
    }

    static func setCurrentDelegate(_ delegate: UISearchControllerDelegate?, to object: UISearchController) {
        object.delegate = delegate
    }

    static func registerKnownImplementations() {
        self.register(make: { RxUISearchControllerDelegate.init(parentObject: $0, delegateProxy: RxUISearchControllerDelegate.self) })
    }

    fileprivate let didDismiss = PublishSubject<UISearchController>()
    func didDismissSearchController(_ searchController: UISearchController) {
        didDismiss.onNext(searchController)
    }
}

extension Reactive where Base: UISearchController {
    private var searchResultsUpdating: RxUISearchResultsUpdating {
        RxUISearchResultsUpdating.proxy(for: base)
    }

    private var delegate: RxUISearchControllerDelegate {
        RxUISearchControllerDelegate.proxy(for: base)
    }

    var searchText: Observable<String?> {
        searchResultsUpdating.updates
            .map { $0.searchBar.text }
    }

    var didDismiss: Observable<Void> {
        delegate.didDismiss.map { _ in}
    }
}
