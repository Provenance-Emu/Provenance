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

    /// Computed property to determine what text to display
    private var displayText: String {
        if let value = value, !value.isEmpty {
            return value
        } else if isEditable {
            return "Tap to edit"
        } else {
            return "Not available"
        }
    }

    /// Computed property to determine text color
    private var textColor: Color {
        if value == nil || value?.isEmpty == true {
            return isEditable ? .gray.opacity(0.7) : .gray
        } else {
            return .primary
        }
    }

    var body: some View {
        HStack {
            // Label side - right aligned
            Text(label + ":")
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundColor(.secondary)

            // Value side - left aligned with placeholder for empty values
            HStack {
                Text(displayText)
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isEditable {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                }
            }
            .contentShape(Rectangle()) // Make entire area tappable
            .onTapGesture {
                if isEditable {
                    #if !os(tvOS)
                    Haptics.impact(style: .light)
                    #endif
                    onLongPress?()
                }
            }
        }
        .padding(.vertical, 4)
    }
}
