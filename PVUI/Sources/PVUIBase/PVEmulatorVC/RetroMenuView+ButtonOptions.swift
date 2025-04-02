import SwiftUI
import PVSettings
import PVUIBase

// MARK: - Button Options Extensions for RetroMenuView
extension RetroMenuView {
    
    // Button Effect picker view with retrowave styling
    var buttonEffectPickerView: some View {
        ZStack {
            // Retrowave background
            RetroTheme.retroBackground
            
            VStack(spacing: 20) {
                // Header
                RetroTheme.retroTitle("BUTTON EFFECT STYLE")
                    .padding(.top, 30)
                
                // Options list
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(ButtonPressEffect.allCases, id: \.self) { effect in
                            EffectOptionButton(effect: effect, 
                                             selectedEffect: buttonPressEffect,
                                             onSelect: { selectedEffect in
                                                 buttonPressEffect = selectedEffect
                                                 // Add haptic feedback
                                                 UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                 // Dismiss the sheet
                                                 showingButtonEffectPicker = false
                                             })
                        }
                    }
                    .padding(.vertical)
                }
                
                // Close button
                RetroCloseButton(action: {
                    showingButtonEffectPicker = false
                })
                .padding(.bottom, 30)
            }
            .padding()
        }
        .edgesIgnoringSafeArea(.all)
        .preferredColorScheme(.dark)
    }
    
    // Button Sound picker view with retrowave styling
    var buttonSoundPickerView: some View {
        ZStack {
            // Retrowave background
            RetroTheme.retroBackground
            
            VStack(spacing: 20) {
                // Header
                RetroTheme.retroTitle("BUTTON SOUND EFFECT")
                    .padding(.top, 30)
                
                // Options list
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(ButtonSound.allCases, id: \.self) { sound in
                            SoundOptionButton(sound: sound, 
                                            selectedSound: buttonSound,
                                            onSelect: { selectedSound in
                                                buttonSound = selectedSound
                                                // Play sample sound when selected
                                                if selectedSound != .none {
                                                    playButtonSound(selectedSound)
                                                }
                                                // Add haptic feedback
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                // Dismiss the sheet
                                                showingButtonSoundPicker = false
                                            })
                        }
                    }
                    .padding(.vertical)
                }
                
                // Close button
                RetroCloseButton(action: {
                    showingButtonSoundPicker = false
                })
                .padding(.bottom, 30)
            }
            .padding()
        }
        .edgesIgnoringSafeArea(.all)
        .preferredColorScheme(.dark)
    }
    
    // Helper function to play button sound
    func playButtonSound(_ sound: ButtonSound) {
        PVUIBase.ButtonSoundGenerator.shared.playSound(sound, pan: 0, volume: 1.0)
    }
}

// MARK: - Helper Components

// Effect Option Button Component
struct EffectOptionButton: View {
    let effect: ButtonPressEffect
    let selectedEffect: ButtonPressEffect
    let onSelect: (ButtonPressEffect) -> Void
    
    var body: some View {
        Button {
            onSelect(effect)
        } label: {
            EffectOptionContent(effect: effect, isSelected: selectedEffect == effect)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
}

// Effect Option Content Component
struct EffectOptionContent: View {
    let effect: ButtonPressEffect
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(effect.description)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text(effect.subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(RetroTheme.retroBlue)
            }
            
            Spacer()
            
            // Selected indicator
            if isSelected {
                RetroCheckmark()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RetroCardBackground(isSelected: isSelected)
        )
    }
}

// Sound Option Button Component
struct SoundOptionButton: View {
    let sound: ButtonSound
    let selectedSound: ButtonSound
    let onSelect: (ButtonSound) -> Void
    
    var body: some View {
        Button {
            onSelect(sound)
        } label: {
            SoundOptionContent(sound: sound, isSelected: selectedSound == sound)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
}

// Sound Option Content Component
struct SoundOptionContent: View {
    let sound: ButtonSound
    let isSelected: Bool
    
    var body: some View {
        HStack {
            // Sound icon
            RetroSoundIcon(sound: sound)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(sound.description)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text(sound.subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(RetroTheme.retroBlue)
            }
            
            Spacer()
            
            // Selected indicator with glow effect
            if isSelected {
                RetroSelectedIndicator()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RetroCardBackground(isSelected: isSelected)
        )
    }
}

// Reusable Retro Card Background
struct RetroCardBackground: View {
    let isSelected: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? 
                        AnyShapeStyle(LinearGradient(
                            gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple, RetroTheme.retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )) : AnyShapeStyle(RetroTheme.retroPurple.opacity(0.5)),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: isSelected ? RetroTheme.retroPink.opacity(0.5) : Color.clear, radius: 8)
    }
}

// Reusable Retro Checkmark
struct RetroCheckmark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RetroTheme.retroBlack)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple, RetroTheme.retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ), 
                            lineWidth: 2
                        )
                )
            
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .shadow(color: RetroTheme.retroPink.opacity(0.6), radius: 5)
    }
}

// Reusable Retro Selected Indicator
struct RetroSelectedIndicator: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 24))
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple, RetroTheme.retroBlue]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .shadow(color: RetroTheme.retroPink.opacity(0.8), radius: 4)
    }
}

// Reusable Retro Sound Icon
struct RetroSoundIcon: View {
    let sound: ButtonSound
    
    var body: some View {
        ZStack {
            Circle()
                .fill(RetroTheme.retroBlack)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple, RetroTheme.retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ), 
                            lineWidth: 1.5
                        )
                )
            
            Image(systemName: sound == .none ? "speaker.slash" : "speaker.wave.2")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.trailing, 8)
    }
}

// Reusable Retro Close Button
struct RetroCloseButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("CLOSE")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 120, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple, RetroTheme.retroBlue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ), 
                                    lineWidth: 1.5
                                )
                        )
                )
                .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
