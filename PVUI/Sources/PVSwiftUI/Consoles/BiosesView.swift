//
//  BiosesView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes

struct BiosesView: View {
    let console: PVSystem

    var body: some View {
        VStack {
            GamesDividerView()
            ForEach(console.bioses, id: \.self) { bios in
                BiosRowView(bios: bios.warmUp())
                GamesDividerView()
            }
        }
    }
}
