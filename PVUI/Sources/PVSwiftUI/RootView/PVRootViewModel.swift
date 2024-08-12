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

@available(iOS 14, tvOS 14, *)
public class PVRootViewModel: ObservableObject {

    @Published public var sortConsolesAscending: Bool = true
    @Published public var sortGamesAscending: Bool = true
    @Published public var viewGamesAsGrid: Bool = true

    public init() {}
}
