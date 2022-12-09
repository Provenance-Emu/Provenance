//
//  SearchBar.swift
//  Provenance
//
//  Created by Ian Clawson on 2/10/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//
//  From: https://github.com/Geri-Borbas/iOS.Blog.SwiftUI_Search_Bar_in_Navigation_Bar

import Foundation
import SwiftUI

@available(iOS 14, tvOS 14, *)
class SearchBar: NSObject, ObservableObject {

    @Published var text: String = ""
    let searchController: UISearchController = UISearchController(searchResultsController: nil)

    override init() {
        super.init()
        self.searchController.obscuresBackgroundDuringPresentation = false
        self.searchController.searchResultsUpdater = self
    }
}

@available(iOS 14, tvOS 14, *)
extension SearchBar: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {

        // Publish search bar text changes.
        if let searchBarText = searchController.searchBar.text {
            self.text = searchBarText
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct SearchBarModifier: ViewModifier {

    let searchBar: SearchBar

    func body(content: Content) -> some SwiftUI.View {
        content
            .overlay(
                ViewControllerResolver { viewController in
                    #if !os(tvOS)
                        viewController.navigationItem.searchController = self.searchBar.searchController
                    #else
                    // TODO: something here?
                    #endif
                }
                    .frame(width: 0, height: 0)
            )
    }
}

@available(iOS 14, tvOS 14, *)
extension SwiftUI.View {
    func add(_ searchBar: SearchBar) -> some SwiftUI.View {
        return self.modifier(SearchBarModifier(searchBar: searchBar))
    }
}
