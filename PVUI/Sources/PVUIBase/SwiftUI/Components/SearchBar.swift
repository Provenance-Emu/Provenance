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
        searchBar.searchTextField.textColor = UIColor(RetroTheme.retroBlue)
        searchBar.searchTextField.tintColor = UIColor(RetroTheme.retroPink)
        
        // Style the search text field
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            textField.layer.cornerRadius = 10
            textField.layer.borderWidth = 1.5
            
            // Create gradient border - note this is simplified as UIKit doesn't support gradients as easily
            textField.layer.borderColor = UIColor(RetroTheme.retroPurple).cgColor
        }

        super.init()

        self.searchController.obscuresBackgroundDuringPresentation = false
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

public struct PVSearchBar: View {
    @Binding public var text: String
    @State private var isSearching: Bool = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    public init(text: Binding<String>) {
        _text = text
    }
    
    public var body: some View {
        HStack {
            HStack {
                // Magnifying glass icon with animation
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isSearching ? RetroTheme.retroPink : Color.gray)
                    .animation(.easeInOut(duration: 0.2), value: isSearching)
                
                // Search text field
                TextField("SEARCH", text: $text, onEditingChanged: { editing in
                    withAnimation {
                        isSearching = editing
                    }
                })
                .foregroundColor(RetroTheme.retroBlue)
                .font(.system(size: 14, weight: .medium))
                
                // Clear button
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(RetroTheme.retroPurple.opacity(0.8))
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.retroBlack.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: RetroTheme.retroBlue.opacity(0.5), radius: 3, x: 0, y: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }
}
