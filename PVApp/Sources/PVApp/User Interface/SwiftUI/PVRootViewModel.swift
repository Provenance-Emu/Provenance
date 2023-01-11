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

@available(iOS 15, tvOS 15, *)
class PVRootViewModel: ObservableObject {

    @Published var sortConsolesAscending: Bool = true
    @Published var sortGamesAscending: Bool = true
    @Published var viewGamesAsGrid: Bool = true

    init() {}
}
#endif
