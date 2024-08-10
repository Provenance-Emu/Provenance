//
//  View+Ext.swift
//  Provenance
//
//  Created by Ian Clawson on 2/4/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI

@available(iOS 14, tvOS 14, *)
extension SwiftUI.View {
    @ViewBuilder
    func `if`<Content: SwiftUI.View>(_ condition: @autoclosure () -> Bool, transform: (Self) -> Content) -> some SwiftUI.View {
       if condition() {
           transform(self)
       } else {
           self
       }
   }
}

@available(iOS 14, tvOS 14, *)
extension UIColor {
    var swiftUIColor: Color {
        return Color(self)
    }
}

#endif
