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

extension BIOSStatus.State {
    var biosStatusImageName: String {
        switch self {
        case .missing: return "bios_empty"
        case .mismatch:  return "bios_empty"
        case .match: return "bios_filled"
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct BiosRowView: SwiftUI.View {

    var bios: PVBIOS

    func biosState() -> BIOSStatus.State {
        return (bios as BIOSStatusProvider).status.state
    }

    var body: some SwiftUI.View {
        HStack(alignment: .center, spacing: 0) {
            Image(biosState().biosStatusImageName).resizable().scaledToFit()
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
            VStack(alignment: .leading) {
                Text("\(bios.descriptionText)")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white)
                Text("\(bios.expectedMD5.uppercased()) : \(bios.expectedSize) bytes")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor)
            }
            Spacer()
            HStack(alignment: .center, spacing: 4) {
                switch biosState() {
                case .match:
                    Image(systemName: "checkmark")
                        .foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor)
                        .font(.system(size: 13, weight: .light))
                case .missing:
                    Text("Missing")
                        .font(.system(size: 12))
                        .foregroundColor(Color.yellow)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.yellow)
                        .font(.system(size: 12, weight: .light))
                case let .mismatch(_):
                    Text("Mismatch")
                        .font(.system(size: 12))
                        .foregroundColor(Color.red)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.red)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 40)
    }
}
#endif
