import SwiftUI
import struct PVUIBase.IconImage
import struct PVUIBase.NeumorphismView
import PVThemes
import PVLogging

// Helper type for gradients to avoid compiler issues
typealias RetroGradient = LinearGradient

enum AppIconOption: String, CaseIterable {
    case `default` = "AppIcon"
    case bit1 = "AppIcon-8bit1"
    case bit2 = "AppIcon-8bit2"
    case bit3 = "AppIcon-8bit3"
    case bit4 = "AppIcon-8bit4"
    case bit5 = "AppIcon-8bit5"
    case blueNegative = "AppIcon-Blue-Negative"
    case blue = "AppIcon-Blue"
    case cyan = "AppIcon-Cyan"
    case gem = "AppIcon-Gem"
    case gold = "AppIcon-Gold"
    case paint1 = "AppIcon-Paint1"
    case paint2 = "AppIcon-Paint2"
    case purple = "AppIcon-Purple"
    case seafoam = "AppIcon-Seafoam"
    case yellow = "AppIcon-Yellow"

    /// User-friendly display name
    var displayName: String {
        switch self {
        case .default: return "Default"
        case .bit1: return "8-Bit Style 1"
        case .bit2: return "8-Bit Style 2"
        case .bit3: return "8-Bit Style 3"
        case .bit4: return "8-Bit Style 4"
        case .bit5: return "8-Bit Style 5"
        case .blueNegative: return "Blue Negative"
        case .blue: return "Blue"
        case .cyan: return "Cyan"
        case .gem: return "Gem"
        case .gold: return "Gold"
        case .paint1: return "Paint Style 1"
        case .paint2: return "Paint Style 2"
        case .purple: return "Purple"
        case .seafoam: return "Seafoam"
        case .yellow: return "Yellow"
        }
    }
}

struct AppIconSelectorView: View {
    @StateObject private var iconManager = IconManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared

    /// Smaller grid items for better layout
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 100), spacing: 20)
    ]
    
    // Track the currently selected icon for animation
    @State private var selectedOption: AppIconOption? = nil
    @State private var showFeedback = false
    @State private var feedbackMessage = ""
    @State private var isSuccess = true

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
               currentIcon
                sectionTitle
                iconGrid
            }
        }
        .onAppear {
            // Debug: Print available images
            let outputString = AppIconOption.allCases.reduce(into: "") { result, option in
                if UIImage(named: option.rawValue, in: .main, with: nil) != nil {
                    result += "✅ Found icon: \(option.rawValue)\n"
                } else {
                    result += "❌ Missing icon: \(option.rawValue)\n"
                }
            }
            DLOG(outputString)
        }
    }
    
    // Helper function for title gradient
    private func titleGradient() -> some ShapeStyle {
        RetroGradient(
            gradient: Gradient(colors: [
                themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                RetroTheme.retroPurple
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Helper function for feedback message styling
    private func feedbackMessageView() -> some View {
        Group {
            if showFeedback {
                Text(feedbackMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        isSuccess ?
                        RetroGradient(
                            gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        RetroGradient(
                            gradient: Gradient(colors: [RetroTheme.retroPink, Color.red]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSuccess ? RetroTheme.retroBlue : RetroTheme.retroPink,
                                lineWidth: 1
                            )
                    )
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // Current icon border
    private func currentIconBorder() -> some View {
        RoundedRectangle(cornerRadius: 25)
            .strokeBorder(
                RetroGradient(
                    gradient: Gradient(colors: [
                        themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                        RetroTheme.retroPurple,
                        RetroTheme.retroBlue
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 3
            )
            .shadow(color: (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.7), radius: 5)
    }
    
    var currentIcon: some View {
        // Current icon preview with retrowave styling
        VStack(spacing: 16) {
            Text("CURRENT APP ICON")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(titleGradient())
                .shadow(color: (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.6), radius: 3)

            // Current icon with retrowave border
            ZStack {
                // Background with grid pattern
                RetroTheme.RetroGridView()
                    .opacity(0.15)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                
                // Icon image
                IconImage(
                    iconName: iconManager.currentIconName ?? "AppIcon",
                    size: 180
                )
                .padding(8)
                
                // Neon border
                currentIconBorder()
            }
            .frame(width: 200, height: 200)
            
            // Status message
            feedbackMessageView()
        }
        .padding(.top, 24)
    }
    
    var sectionTitle: some View {
        // Section title with retrowave styling
        Text("SELECT NEW ICON")
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(
                RetroGradient(
                    gradient: Gradient(colors: [
                        RetroTheme.retroBlue,
                        themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .shadow(color: RetroTheme.retroBlue.opacity(0.6), radius: 2)
            .padding(.bottom, 8)
    }
    
    // Helper function to create icon border gradient
    private func iconBorderGradient(isSelected: Bool) -> AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(RetroGradient(
                gradient: Gradient(colors: [
                    themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                    RetroTheme.retroPurple,
                    RetroTheme.retroBlue
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        } else {
            return AnyShapeStyle(Color.gray.opacity(0.5))
        }
    }
    
    // Helper function to create text gradient
    private func textGradient(isSelected: Bool) -> AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(RetroGradient(
                gradient: Gradient(colors: [
                    themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                    RetroTheme.retroPurple
                ]),
                startPoint: .leading,
                endPoint: .trailing
            ))
        } else {
            return AnyShapeStyle(Color.gray)
        }
    }
    
    // Single icon view to simplify the main grid
    private func iconView(for option: AppIconOption, isSelected: Bool, isChanging: Bool) -> some View {
        VStack(spacing: 12) {
            // Icon with retrowave border
            ZStack {
                // Background
                Color.black.opacity(0.3)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Icon image
                IconImage(
                    iconName: option.rawValue,
                    size: 64
                )
                
                // Border
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        iconBorderGradient(isSelected: isSelected),
                        lineWidth: isSelected ? 2 : 1
                    )
                
                // Loading indicator
                if isChanging {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: RetroTheme.retroPink))
                        .scaleEffect(1.5)
                        .background(Color.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // Selected indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(RetroTheme.retroBlue)
                        .shadow(color: RetroTheme.retroBlue.opacity(0.8), radius: 3)
                        .position(x: 64, y: 16)
                }
            }
            .frame(width: 80, height: 80)
            .shadow(color: isSelected ? (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.6) : Color.clear, radius: 4)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)

            // Icon name with retrowave styling
            Text(option.displayName)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundStyle(textGradient(isSelected: isSelected))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 30)
        }
        .frame(width: 100, height: 120)
    }
    
    var iconGrid: some View {
        // Icon grid with retrowave styling
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(AppIconOption.allCases, id: \.self) { option in
                let isSelected = option.rawValue == (iconManager.currentIconName ?? "AppIcon")
                let isChanging = selectedOption == option && iconManager.isChangingIcon
                
                iconView(for: option, isSelected: isSelected, isChanging: isChanging)
                    .onTapGesture {
                        changeAppIcon(to: option)
                    }
            }
        }
        .padding(.horizontal)
    }

    private func changeAppIcon(to option: AppIconOption) {
        // Skip if this is already the current icon
        let iconName = option == .default ? nil : option.rawValue
        if iconName == iconManager.currentIconName {
            return
        }
        
        // Track which option is being changed
        selectedOption = option
        
        // Use the IconManager to change the icon
        iconManager.changeIcon(to: iconName)
        
        // Show feedback with animation
        withAnimation {
            showFeedback = true
            feedbackMessage = "Changing to \(option.displayName)..."
            isSuccess = true
        }
        
        // Update feedback when the change completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                if let error = iconManager.lastError {
                    feedbackMessage = "Error: \(error)"
                    isSuccess = false
                } else if !iconManager.isChangingIcon {
                    feedbackMessage = "Changed to \(option.displayName)"
                    isSuccess = true
                    
                    // Hide success message after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showFeedback = false
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    AppIconSelectorView()
}
#endif
