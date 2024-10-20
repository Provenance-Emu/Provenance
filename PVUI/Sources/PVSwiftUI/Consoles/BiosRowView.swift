//
//  BiosRowView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/28/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVPrimitives
import PVThemes
import PVRealm

extension BIOSStatus.State {
    var biosStatusImageName: String {
        switch self {
        case .missing: return "bios_empty"
        case .mismatch:  return "bios_empty"
        case .match: return "bios_filled"
        }
    }
}

struct BiosRowView: SwiftUI.View {

    var bios: PVBIOS

    @MainActor
    @State
    var biosState: BIOSStatus.State? = nil

    var body: some SwiftUI.View {
        

        return HStack(alignment: .center, spacing: 0) {
            Image(biosState?.biosStatusImageName ?? BIOSStatus.State.missing.biosStatusImageName).resizable().scaledToFit()
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
            VStack(alignment: .leading) {
                Text("\(bios.descriptionText)")
                    .font(.footnote)
                    .foregroundColor(Color.white)
                Text("\(bios.expectedMD5.uppercased()) : \(bios.expectedSize) bytes")
                    .font(.caption2)
                    .foregroundColor(ThemeManager.shared.currentTheme.gameLibraryText.swiftUIColor)
            }
            Spacer()
            HStack(alignment: .center, spacing: 4) {
                switch biosState {
                case .match:
                    Image(systemName: "checkmark")
                        .foregroundColor(ThemeManager.shared.currentTheme.gameLibraryText.swiftUIColor)
                        .font(.footnote.weight(.light))
                case .missing:
                    Text("Missing")
                        .font(.caption)
                        .foregroundColor(Color.yellow)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.yellow)
                        .font(.caption.weight(.light))
                case .mismatch(_):
                    Text("Mismatch")
                        .font(.caption)
                        .foregroundColor(Color.red)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.red)
                        .font(.caption.weight(.medium))
                case .none:
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(Color.red)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.red)
                        .font(.caption.weight(.medium))
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 40)
        .task { @MainActor in
            let biosState  = (bios as BIOSStatusProvider).status
            self.biosState = biosState.state
        }
    }
}
#endif
