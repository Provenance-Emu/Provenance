//
//  CoreOptionsView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import PVCoreBridge

/// View that provides access to core-specific options
///
/// This view displays a list of all cores that implement the CoreOptional protocol,
/// allowing users to view and modify core-specific options. Each core can define its
/// own set of options, which can be boolean toggles, numeric ranges, string values,
/// or selections from predefined lists.
///
/// Options are automatically persisted between app launches, and can be reset to their
/// default values either individually or all at once.
public struct CoreOptionsView: View {

    /// Initialize a new CoreOptionsView
    public init() {}

    /// The body of the view
    public var body: some View {
        CoreOptionsListView()
    }
}
