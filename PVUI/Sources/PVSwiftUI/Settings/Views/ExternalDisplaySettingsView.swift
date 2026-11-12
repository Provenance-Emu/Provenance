//
//  ExternalDisplaySettingsView.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-03-24.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Settings page for a connected display. Presented via NavigationLink from the Video
//  section. The options themselves are shared with the pause menu.
//

#if os(iOS)
import SwiftUI
import PVUIBase

struct ExternalDisplaySettingsView: View {
    var body: some View {
        ExternalDisplayOptionsView()
    }
}
#endif
