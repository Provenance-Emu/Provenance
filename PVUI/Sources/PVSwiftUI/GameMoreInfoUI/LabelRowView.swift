//
//  LabelRowView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 12/9/24.
//

import SwiftUI

/// A reusable view for displaying a label and value pair with optional editing
struct LabelRowView: View {
    let label: String
    let value: String?
    var onLongPress: (() -> Void)?
    var isEditable: Bool = true

    var body: some View {
        HStack {
            // Label side - right aligned
            Text(label + ":")
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundColor(.secondary)

            // Value side - left aligned
            Text(value ?? "")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle()) // Make entire area tappable
                .onLongPressGesture {
                    if isEditable {
                        onLongPress?()
                    }
                }
        }
        .padding(.vertical, 4)
    }
}
