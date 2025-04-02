import SwiftUI
import PVUIBase
import PVSettings

// MARK: - Button Effect Option Item
struct ButtonEffectOptionItem: View {
    let effect: ButtonPressEffect
    @Binding var selectedEffect: ButtonPressEffect
    
    var body: some View {
        Button {
            selectedEffect = effect
            // Add haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
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
                if selectedEffect == effect {
                    SelectedCheckmark()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                selectedEffect == effect ? 
                                AnyShapeStyle(LinearGradient(
                                    gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple, RetroTheme.retroBlue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )) : AnyShapeStyle(RetroTheme.retroPurple.opacity(0.5)),
                                lineWidth: selectedEffect == effect ? 2 : 1
                            )
                    )
            )
            .shadow(color: selectedEffect == effect ? RetroTheme.retroPink.opacity(0.5) : Color.clear, radius: 8)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
}

// MARK: - Button Sound Option Item
struct ButtonSoundOptionItem: View {
    let sound: ButtonSound
    @Binding var selectedSound: ButtonSound
    let playSound: (ButtonSound) -> Void
    
    var body: some View {
        Button {
            selectedSound = sound
            // Play sample sound when selected
            if sound != .none {
                playSound(sound)
            }
            // Add haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack {
                // Sound icon
                SoundIconView(sound: sound)
                
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
                if selectedSound == sound {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(LinearGradient(
                            gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple, RetroTheme.retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .shadow(color: RetroTheme.retroPink.opacity(0.8), radius: 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                selectedSound == sound ? 
                                AnyShapeStyle(LinearGradient(
                                    gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple, RetroTheme.retroBlue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )) : AnyShapeStyle(RetroTheme.retroPurple.opacity(0.5)),
                                lineWidth: selectedSound == sound ? 2 : 1
                            )
                    )
            )
            .shadow(color: selectedSound == sound ? RetroTheme.retroPink.opacity(0.5) : Color.clear, radius: 8)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
}

// MARK: - Sound Icon View
struct SoundIconView: View {
    let sound: ButtonSound
    
    var body: some View {
        ZStack {
            Circle()
                .fill(RetroTheme.retroBlack)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .strokeBorder(RetroTheme.retroGradient, lineWidth: 1.5)
                )
            
            Image(systemName: sound == .none ? "speaker.slash" : "speaker.wave.2")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
        }
        .padding(.trailing, 8)
    }
}

// MARK: - Selected Checkmark
struct SelectedCheckmark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RetroTheme.retroBlack)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .strokeBorder(RetroTheme.retroGradient, lineWidth: 2)
                )
            
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
        }
        .shadow(color: RetroTheme.retroPink.opacity(0.6), radius: 5)
    }
}

// MARK: - Button Effect Picker View
struct ButtonEffectPickerView: View {
    @Binding var buttonPressEffect: ButtonPressEffect
    
    var body: some View {
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
                            ButtonEffectOptionItem(effect: effect, selectedEffect: $buttonPressEffect)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .padding()
        }
        .edgesIgnoringSafeArea(.all)
        .navigationBarTitle("", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("BUTTON EFFECT")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
            }
        }
    }
}

// MARK: - Button Sound Picker View
struct ButtonSoundPickerView: View {
    @Binding var buttonSound: ButtonSound
    let playSound: (ButtonSound) -> Void
    
    var body: some View {
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
                            ButtonSoundOptionItem(
                                sound: sound,
                                selectedSound: $buttonSound,
                                playSound: playSound
                            )
                        }
                    }
                    .padding(.vertical)
                }
            }
            .padding()
        }
        .edgesIgnoringSafeArea(.all)
        .navigationBarTitle("", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SOUND EFFECT")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
            }
        }
    }
}
