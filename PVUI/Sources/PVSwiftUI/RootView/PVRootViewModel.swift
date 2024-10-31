//
//  PVRootViewModel.swift
//  Provenance
//
//  Created by Ian Clawson on 2/13/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// ViewModel for the Root view
public class PVRootViewModel: ObservableObject {

    /// Whether to sort consoles in ascending order
    @Published public var sortConsolesAscending: Bool = true
    
    /// Whether to sort games in ascending order
    @Published public var sortGamesAscending: Bool = true
    
    /// Whether to show games in a grid or list
    @Published public var viewGamesAsGrid: Bool = true
    
    public init() {}
}
