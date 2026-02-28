//
//  PremiumThemedPicker.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2025-04-03.
//

import SwiftUI
import UIKit
#if canImport(FreemiumKit)
import FreemiumKit
#endif
import PVThemes

/// A premium-gated picker component with retrowave styling for enum values
public struct PremiumThemedPicker<T: CaseIterable & Identifiable & CustomStringConvertible, Label: View>: View where T: Hashable {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var selection: T
    let label: Label
    let options: [T]
    
    public init(selection: Binding<T>, options: [T]? = nil, @ViewBuilder label: () -> Label) {
        self._selection = selection
        self.label = label()
        self.options = options ?? Array(T.allCases as! [T])
    }
    
#if canImport(FreemiumKit)
    public var body: some View {
    #if !os(tvOS)
        PaidFeatureView {
            VStack(alignment: .leading) {
                label
                Picker.init(selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(option.description.uppercased()).tag(option)
                    }
                } label: {
                    label
                }
                .pickerStyle(.wheel)
                .frame(height: 100)
                .onChange(of: selection) { newValue in
                    selection = newValue
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .background(Color.retroBlack.opacity(0.5))
                .cornerRadius(8)
                .padding(.top, 8)
            }
        } lockedView: {
            ZStack {
                Color(.clear)
                VStack(alignment: .leading) {
                    HStack {
                        label
                        Spacer()
                        // Lock icon + PLUS badge
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("PLUS")
                                .font(.system(size: 9, weight: .heavy))
                        }
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.retroPink.opacity(0.15))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.retroPink.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                    }

                    // Retrowave-styled picker (disabled)
                    HStack(spacing: 12) {
                        ForEach(options) { option in
                            RetroOptionButton(
                                option: option,
                                isSelected: selection == option,
                                action: { }
                            )
                        }
                    }
                    .padding(.top, 8)
                }
                .opacity(0.7)
                .disabled(true)
            }
        }
        .freemiumKitColorReset()
        #else
        PaidFeatureView {
            VStack(alignment: .leading) {
                label

                Picker("", selection: $selection) {
                    ForEach(options) { option in
                        Text(option.description).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        } lockedView: {
            ZStack {
                Color(.clear)
                VStack(alignment: .leading) {
                    HStack {
                        label
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("PLUS")
                                .font(.system(size: 9, weight: .heavy))
                        }
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.retroPink.opacity(0.15))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.retroPink.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                    }

                    Picker("", selection: $selection) {
                        ForEach(options) { option in
                            Text(option.description).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .opacity(0.7)
                .disabled(true)
            }
        }
        .freemiumKitColorReset()
        #endif
    }
#else
    public var body: some View {
        VStack(alignment: .leading) {
            label
            
            Picker("", selection: $selection) {
                ForEach(options) { option in
                    Text(option.description).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }
#endif
}
