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

public class SearchBar: NSObject, ObservableObject {

    @Published public var text: String = ""
    let searchController: UISearchController

    #if os(tvOS)
    // Cannot be nil on tvOS,
    public required init(searchResultsController: UIViewController) {
        searchController = UISearchController(searchResultsController: searchResultsController)

        super.init()

        self.searchController.obscuresBackgroundDuringPresentation = false
        self.searchController.searchResultsUpdater = self
    }
    #else
    public required init(searchResultsController: UIViewController? = nil) {
        searchController = UISearchController(searchResultsController: searchResultsController)

        // Apply retrowave styling to UIKit search bar
        let searchBar = searchController.searchBar
        let palette = ThemeManager.shared.currentPalette
        searchBar.searchTextField.textColor = palette.gameLibraryText
        searchBar.searchTextField.tintColor = palette.defaultTintColor

        // Style the search text field with theme-aware background
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.backgroundColor = palette.dark
                ? UIColor.black.withAlphaComponent(0.7)
                : UIColor.white.withAlphaComponent(0.9)
            textField.layer.cornerRadius = RetroPauseChrome.searchFieldCornerRadius()
            textField.layer.borderWidth = 1.5

            // Create gradient border - note this is simplified as UIKit doesn't support gradients as easily
            textField.layer.borderColor = palette.defaultTintColor.cgColor
        }

        super.init()

        self.searchController.obscuresBackgroundDuringPresentation = false
        self.searchController.hidesNavigationBarDuringPresentation = false
        self.searchController.searchResultsUpdater = self
    }
    #endif
}

extension SearchBar: UISearchResultsUpdating {

    public func updateSearchResults(for searchController: UISearchController) {

        // Publish search bar text changes.
        if let searchBarText = searchController.searchBar.text {
            self.text = searchBarText
        }
    }
}

public struct SearchBarModifier: ViewModifier {

    public let searchBar: SearchBar

    public init(searchBar: SearchBar) {
        self.searchBar = searchBar
    }

    public func body(content: Content) -> some SwiftUI.View {
        content
            .overlay(
                ViewControllerResolver { viewController in
                    #if !os(tvOS)
                        if let navController = viewController.navigationController {
                            navController.navigationBar.prefersLargeTitles = false
                        }
                        viewController.navigationItem.hidesSearchBarWhenScrolling = false
                        self.searchBar.searchController.hidesNavigationBarDuringPresentation = false
                        viewController.navigationItem.searchController = self.searchBar.searchController
                    #else
                    // TODO: something here?
                    #endif
                }
                    .frame(width: 0, height: 0)
            )
    }
}

public extension SwiftUI.View {
    func add(_ searchBar: SearchBar) -> some SwiftUI.View {
        return self.modifier(SearchBarModifier(searchBar: searchBar))
    }
}
