import SwiftUI
import PVUIBase
import struct PVUIBase.PVSearchBar

struct ConfigListContent: View {
    @ObservedObject var filterVM: ConfigFilterViewModel
    @ObservedObject var editVM: ConfigEditViewModel

    @EnvironmentObject private var configEditor: RetroArchConfigEditorViewModel
    
    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var scanlineOffset: CGFloat = 0

    var body: some View {
        let groupedKeys = Dictionary(grouping: filteredKeys) { key in
            key.components(separatedBy: "_").first ?? "Other"
        }

        return ZStack {
            // RetroWave background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Grid background
            RetroGridForSettings()
                .edgesIgnoringSafeArea(.all)
                .opacity(0.5)
            
            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    // Search bar with retrowave styling
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.retroPink)
                        TextField("Search Config", text: $filterVM.searchText)
                            .foregroundColor(.white)
                            .accentColor(.retroBlue)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                    )
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Sections
                    ForEach(groupedKeys.keys.sorted(), id: \.self) { section in
                        CollapsibleSection(title: section) {
                            VStack(spacing: 8) {
                                ForEach(groupedKeys[section] ?? [], id: \.self) { key in
                                    ConfigRowView(
                                        key: key,
                                        value: configEditor.configValues[key] ?? "",
                                        description: configEditor.configDescriptions[key] ?? "",
                                        isChanged: editVM.isChanged(key),
                                        isDefault: editVM.isDefaultValue(key)
                                    )
                                    .onTapGesture {
                                        editVM.prepareForEditing(key: key)
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            // Start animation for glow effect
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.9
            }
        }
    }

    private var filteredKeys: [String] {
        let keys = filterVM.showOnlyModified ? filterVM.modifiedKeys : configEditor.configKeys
        if filterVM.searchText.isEmpty {
            return keys
        } else {
            return keys.filter { $0.localizedCaseInsensitiveContains(filterVM.searchText) }
        }
    }
}

struct ConfigRowView: View {
    let key: String
    let value: String
    let description: String
    let isChanged: Bool
    let isDefault: Bool
    
    @EnvironmentObject private var configEditor: RetroArchConfigEditorViewModel
    @State private var isHovered = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(key)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isChanged ? .retroPink : .white)
                    .shadow(color: isChanged ? .retroPink.opacity(0.7) : .clear, radius: 2, x: 0, y: 0)
                
                Text(configEditor.stripQuotes(from: value))
                    .font(.system(size: 14))
                    .foregroundColor(isChanged ? .retroPink.opacity(0.9) : .retroBlue)
                
                if !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }

            Spacer()

            if isChanged {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.retroPink)
                    .shadow(color: .retroPink.opacity(0.7), radius: 3, x: 0, y: 0)
            } else if isDefault {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.retroBlue)
                    .shadow(color: .retroBlue.opacity(0.7), radius: 3, x: 0, y: 0)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: isChanged ? 
                                                 [.retroPink, .retroPurple] : 
                                                 [.retroBlue.opacity(0.7), .retroPurple.opacity(0.7)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: isHovered ? 1.5 : 0.5
                        )
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
#if !os(tvOS)
        .onHover { hovering in
            isHovered = hovering
        }
#endif
    }
}
