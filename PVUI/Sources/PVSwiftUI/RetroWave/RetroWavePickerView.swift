//
//  RetroWavePickerView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/1/25.
//

import SwiftUI
import PVThemes

/// A custom picker with retrowave styling
public struct RetroWavePickerView<T: Hashable & Identifiable>: View {
    let title: String
    let options: [T]
    @Binding var selection: T
    let displayText: (T) -> String
    
    @State private var isExpanded = false
    @State private var glowOpacity = 0.0
    
    public init(
        title: String,
        options: [T],
        selection: Binding<T>,
        displayText: @escaping (T) -> String
    ) {
        self.title = title
        self.options = options
        self._selection = selection
        self.displayText = displayText
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            // Current selection button
            Button(action: {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(displayText(selection))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(RetroTheme.retroPink)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                )
                .shadow(color: RetroTheme.retroPink.opacity(isExpanded ? 0.5 : 0), radius: 8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Options list when expanded
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(options) { option in
                        Button(action: {
                            selection = option
                            withAnimation(.spring()) {
                                isExpanded = false
                            }
                        }) {
                            HStack {
                                Text(displayText(option))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if option.id == selection.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(RetroTheme.retroPink)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                option.id == selection.id ? 
                                    Color.black.opacity(0.8) : 
                                    Color.clear
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if option.id != options.last?.id {
                            Divider()
                                .background(RetroTheme.retroBlue.opacity(0.3))
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(RetroTheme.retroBlue.opacity(0.5), lineWidth: 1)
                        )
                )
                .shadow(color: RetroTheme.retroPurple.opacity(0.3), radius: 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

// Preview struct for demonstration
private struct PickerOption: Identifiable, Hashable {
    let id = UUID()
    let name: String
}

#Preview {
    let options = [
        PickerOption(name: "Option 1"),
        PickerOption(name: "Option 2"),
        PickerOption(name: "Option 3")
    ]
    
    return VStack {
        RetroWavePickerView(
            title: "Select an option",
            options: options,
            selection: .constant(options[0]),
            displayText: { $0.name }
        )
    }
    .padding()
    .background(RetroTheme.retroBlack)
}
