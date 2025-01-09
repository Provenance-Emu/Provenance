//
//  SettingsIcon.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI

public enum SettingsIcon: Equatable {
    case named(String, Bundle? = nil)
    case sfSymbol(String)

    var image: Image {
        switch self {
        case .named(let name, let bundle):
            if let bundle = bundle {
                return Image(name, bundle: bundle)
            } else {
                return Image(name)
            }
        case .sfSymbol(let name):
            return Image(systemName: name)
        }
    }

    var highlightedImage: Image? {
        switch self {
        case .named(let name, let bundle):
            let highlightedName = name + "-highlighted"
            if let bundle = bundle {
                if bundle.path(forResource: highlightedName, ofType: nil) != nil {
                    return Image(highlightedName, bundle: bundle)
                }
            } else if Bundle.main.path(forResource: highlightedName, ofType: nil) != nil {
                return Image(highlightedName)
            }
            return nil
        case .sfSymbol:
            return nil
        }
    }
}
