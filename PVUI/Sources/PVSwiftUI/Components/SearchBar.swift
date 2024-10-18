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

class SearchBar: NSObject, ObservableObject {

    @Published var text: String = ""
    let searchController: UISearchController
    

    #if os(tvOS)
    // Cannot be nil on tvOS,
    required init(searchResultsController searchResultsController: UIViewController) {
        searchController = UISearchController(searchResultsController: searchResultsController)

        super.init()

        self.searchController.obscuresBackgroundDuringPresentation = false
        self.searchController.searchResultsUpdater = self
    }
    #else
    required init(searchResultsController searchResultsController: UIViewController? = nil) {
        searchController = UISearchController(searchResultsController: searchResultsController)

        super.init()

        self.searchController.obscuresBackgroundDuringPresentation = false
        self.searchController.searchResultsUpdater = self
    }
    #endif
}

extension SearchBar: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {

        // Publish search bar text changes.
        if let searchBarText = searchController.searchBar.text {
            self.text = searchBarText
        }
    }
}

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

extension SwiftUI.View {
    func add(_ searchBar: SearchBar) -> some SwiftUI.View {
        return self.modifier(SearchBarModifier(searchBar: searchBar))
    }
}
