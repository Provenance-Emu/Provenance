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
import PVThemes

class SearchBar: NSObject, ObservableObject {

    @Published var text: String = ""
    let searchController: UISearchController


    #if os(tvOS)
    // Cannot be nil on tvOS,
    required init(searchResultsController: UIViewController) {
        searchController = UISearchController(searchResultsController: searchResultsController)

        super.init()

        self.searchController.obscuresBackgroundDuringPresentation = false
        self.searchController.searchResultsUpdater = self
    }
    #else
    required init(searchResultsController: UIViewController? = nil) {
        searchController = UISearchController(searchResultsController: searchResultsController)
        searchController.searchBar.searchTextField.textColor = ThemeManager.shared.currentPalette.menuHeaderText
//        searchController.searchBar.searchTextField.defaultTextAttributes = [.foregroundColor: ThemeManager.shared.currentPalette.menuHeaderText]

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

struct PVSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            TextField("Search", text: $text)
                .padding(8)
            #if !os(tvOS)
                .background(Color(.systemGray6))
            #endif
                .cornerRadius(8)
                .padding(.horizontal, 8)

            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 8)
            }
        }
        .padding(.vertical, 8)
    }
}
