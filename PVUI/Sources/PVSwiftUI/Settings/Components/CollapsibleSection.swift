//
//  CollapsibleSection.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/9/24.
//

import SwiftUI
import PVSettings
import Defaults
import PVLogging

internal struct CollapsibleSection<Content: View>: View {
    let title: String
    let content: Content
    @Default(.collapsedSections) var collapsedSections
    @State private var isExpanded: Bool

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        self._isExpanded = State(initialValue: !Defaults[.collapsedSections].contains(title))
        VLOG("Init CollapsibleSection '\(title)' - collapsed sections: \(Defaults[.collapsedSections])")
    }

    var body: some View {
        Section {
            if isExpanded {
                content
            }
        } header: {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                    print("Setting isExpanded for '\(title)' to \(isExpanded)")
                    print("Before - collapsed sections: \(collapsedSections)")
                    if isExpanded {
                        collapsedSections.remove(title)
                    } else {
                        collapsedSections.insert(title)
                    }
                    print("After - collapsed sections: \(collapsedSections)")
                }
            }) {
                HStack {
                    Text(title)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}
