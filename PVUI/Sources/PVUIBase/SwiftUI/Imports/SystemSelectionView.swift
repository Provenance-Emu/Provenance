//
//  SystemSelectionView.swift
//  PVUI
//
//  Created by David Proskin on 11/7/24.
//

import SwiftUI
import PVLibrary
import Perception
import PVSystems
import PVThemes

struct SystemSelectionView: View {
    @ObservedObject var item: ImportQueueItem
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var scanlineOffset: CGFloat = 0
    @State private var selectedSystem: SystemIdentifier? = nil

    // Replace delegate with callback
    var onSystemSelected: ((SystemIdentifier, ImportQueueItem) -> Void)?

    var body: some View {
        ZStack {
            // RetroWave background
            RetroTheme.retroBackground
            
            // Grid overlay
            RetroGrid()
                .opacity(0.3)
            
            VStack(spacing: 16) {
                // Retrowave header
                Text("SELECT SYSTEM")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(RetroTheme.retroPink)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 5, x: 0, y: 0)
                
                // System selection list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(item.systems.sorted(), id: \.self) { system in
                            Button(action: {
                                // Set the chosen system with animation
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedSystem = system
                                }
                                
                                // Delay to show selection animation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    // Set the chosen system
                                    item.userChosenSystem = system
                                    
                                    // Call the callback
                                    onSystemSelected?(system, item)
                                    
                                    // Dismiss the view
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }) {
                                HStack {
                                    Text(system.fullName)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity * 0.8), radius: 2, x: 0, y: 0)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(RetroTheme.retroPurple)
                                        .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.black.opacity(0.7))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    ),
                                                    lineWidth: selectedSystem == system ? 2.0 : 1.0
                                                )
                                                .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), 
                                                        radius: selectedSystem == system ? 5 : 2, 
                                                        x: 0, 
                                                        y: 0)
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .onAppear {
            // Start retrowave animations
            withAnimation(Animation.linear(duration: 20).repeatForever(autoreverses: false)) {
                scanlineOffset = 1000
            }
            
            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }
}

#if DEBUG
import PVPrimitives
#Preview {


    let item: ImportQueueItem = {
        let systems: [SystemIdentifier] = [
            .AtariJaguar, .AtariJaguarCD
        ]

        let item = ImportQueueItem(url: .init(fileURLWithPath: "Test.bin"),
                        fileType: .game)
        item.systems = systems
        return item
    }()

    List {
        SystemSelectionView(item: item)
    }
}
#endif
