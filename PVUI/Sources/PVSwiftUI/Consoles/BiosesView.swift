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
    @ObservedRealmObject var console: PVSystem

    var body: some View {
        VStack {
            GamesDividerView()
            ForEach(console.bioses, id: \.expectedFilename) { bios in
                BiosRowView(biosFilename: bios.expectedFilename)
                GamesDividerView()
            }
        }
    }
}
