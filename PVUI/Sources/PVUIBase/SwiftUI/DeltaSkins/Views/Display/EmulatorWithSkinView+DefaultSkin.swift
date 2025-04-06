
//
//  EmulatorWithSkinView+DefaultSkin.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/28/25.
//

import SwiftUI
import PVEmulatorCore
import PVSystems
import PVRealm
import RealmSwift
import PVLibrary
import PVPlists

// MARK: - Retrowave Styling Components

/// Retrowave background with grid and sun
struct RetrowaveBackground: View {
    var body: some View {
        ZStack {
            // Deep blue/purple background
            Color(red: 0.05, green: 0.0, blue: 0.15, opacity: 0.9)
                .edgesIgnoringSafeArea(.all)
            
            // Grid with perspective effect
            RetrowaveGrid()
                .opacity(0.35)
            
            // Sun glow effect
            RetrowaveSun()
                .opacity(0.25)
        }
    }
}

/// Retrowave grid with perspective effect
struct RetrowaveGrid: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let horizonY = height * 0.6
                let centerX = width / 2
                
                // Horizontal grid lines
                for i in 0..<20 {
                    let y = horizonY + CGFloat(i) * CGFloat(i) * 2.0
                    if y < height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                
                // Vertical grid lines with perspective
                for i in 0..<20 {
                    let spacing = width / 20
                    let x = centerX + spacing * CGFloat(i)
                    if x < width {
                        path.move(to: CGPoint(x: x, y: horizonY))
                        path.addLine(to: CGPoint(x: width, y: height))
                    }
                    
                    let x2 = centerX - spacing * CGFloat(i)
                    if x2 > 0 {
                        path.move(to: CGPoint(x: x2, y: horizonY))
                        path.addLine(to: CGPoint(x: 0, y: height))
                    }
                }
            }
            .stroke(Color(red: 0.99, green: 0.11, blue: 0.55, opacity: 0.3), lineWidth: 1)
        }
    }
}

/// Retrowave sun effect
struct RetrowaveSun: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let horizonY = height * 0.6
            
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.99, green: 0.11, blue: 0.55, opacity: 0.7),
                            Color(red: 0.99, green: 0.11, blue: 0.55, opacity: 0.0)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: width * 0.4
                    )
                )
                .frame(width: width * 0.8, height: width * 0.8)
                .position(x: width / 2, y: horizonY)
                .blur(radius: 20)
        }
    }
}

/// Neon text style for buttons
struct NeonText: View {
    let text: String
    let color: Color
    let fontSize: CGFloat
    
    init(_ text: String, color: Color = Color(red: 0.99, green: 0.11, blue: 0.55), fontSize: CGFloat = 14) {
        self.text = text
        self.color = color
        self.fontSize = fontSize
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(.white)
            .shadow(color: color, radius: 2, x: 0, y: 0)
            .shadow(color: color, radius: 4, x: 0, y: 0)
    }
}

// MARK: - Default Controller
extension EmulatorWithSkinView {
    
    /// Create a default skin for a system
    /// - Parameter systemId: The system identifier
    /// - Returns: A default skin for the system
    public static func defaultSkin(for systemId: SystemIdentifier) -> DeltaSkinProtocol {
        return DefaultDeltaSkin(systemId: systemId)
    }
    
    /// Default controller skin as a fallback
    internal func defaultControllerSkin() -> some View {
        // Use a local state variable for the joystick toggle since we can't mutate self
        return DefaultControllerSkinView(
            useJoystick: useJoystick,
            inputHandler: inputHandler,
            systemId: systemId,
            coreInstance: coreInstance
        )
    }
}

// Separate view to handle the default controller skin with its own state
struct DefaultControllerSkinView: View {
    // Initial value from parent
    @State private var useJoystickInternal: Bool
    let inputHandler: DeltaSkinInputHandler
    let systemId: SystemIdentifier?
    let coreInstance: PVEmulatorCore
    
    // State for control layout data
    @State private var controlLayout: [ControlLayoutEntry]? = nil
    
    init(useJoystick: Bool, inputHandler: DeltaSkinInputHandler, systemId: SystemIdentifier?, coreInstance: PVEmulatorCore) {
        self._useJoystickInternal = State(initialValue: useJoystick)
        self.inputHandler = inputHandler
        self.systemId = systemId
        self.coreInstance = coreInstance
    }
    
    var body: some View {
        // Load control layout data when view appears
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                // Only show background in portrait mode with a gradual fade
                if !isLandscape {
                    // Portrait mode - show background with a gradual fade from top to bottom
                    ZStack {
                        // Retrowave background
                        RetrowaveBackground()
                        // Apply a gradient mask for smooth fade from transparent to visible
                            .mask(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .clear, location: 0.0),   // Fully transparent at top
                                        .init(color: .clear, location: 0.3),   // Still transparent at 30%
                                        .init(color: .white, location: 0.7)    // Fully visible at 70%
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
                
                if isLandscape {
                    // Landscape layout - controls positioned at edges with safe area awareness
                    dynamicLandscapeControllerSkin
                        .onAppear {
                            loadControlLayoutData()
                        }
                        .edgesIgnoringSafeArea([]) // Respect safe areas for notch
                } else {
                    // Portrait layout - controls at bottom
                    VStack {
                        Spacer() // Push the controller to the bottom of the screen
                        
                        dynamicControllerSkin
                            .onAppear {
                                loadControlLayoutData()
                            }
                    }
                }
            }
        }
    }
    
    // Landscape-specific layout with controls positioned correctly
    private var landscapeControllerLayout: some View {
        GeometryReader { geometry in
            ZStack {
                // Top row with shoulder buttons, menu and turbo buttons
                VStack {
                    HStack {
                        // Left shoulder buttons
                        HStack(spacing: 15) {
                            shoulderButton(label: "L", color: .gray)
                            shoulderButton(label: "L2", color: .gray)
                            shoulderButton(label: "L3", color: .gray)
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        // Menu and Turbo buttons in center
                        HStack(spacing: 20) {
                            utilityButton(label: "MENU", color: .purple, systemImage: "line.3.horizontal")
                            utilityButton(label: "TURBO", color: .orange, systemImage: "forward.fill")
                        }
                        
                        Spacer()
                        
                        // Right shoulder buttons
                        HStack(spacing: 15) {
                            shoulderButton(label: "R3", color: .gray)
                            shoulderButton(label: "R2", color: .gray)
                            shoulderButton(label: "R", color: .gray)
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Start/Select buttons at the center bottom
                    HStack {
                        Spacer()
                        HStack(spacing: 30) {
                            pillButton(label: "SELECT", color: .black)
                            pillButton(label: "START", color: .black)
                        }
                        .padding(.bottom, 20)
                        Spacer()
                    }
                }
            }
            
            // D-pad on the left side
            VStack {
                Spacer()
                if useJoystickInternal {
                    joystickView()
                } else {
                    dPadView()
                }
                Spacer()
            }
            .frame(width: 150)
            .padding(.leading, 80)
            .position(x: 150, y: geometry.size.height / 2)
            
            // Action buttons on the right side
            VStack {
                Spacer()
                HStack(spacing: 30) {
                    VStack(spacing: 25) {
                        circleButton(label: "Y", color: .yellow)
                        circleButton(label: "X", color: .blue)
                    }
                    
                    VStack(spacing: 25) {
                        circleButton(label: "B", color: .red)
                        circleButton(label: "A", color: .green)
                    }
                }
                Spacer()
            }
            .frame(width: 150)
            .position(x: geometry.size.width - 150, y: geometry.size.height / 2)
        }
    }
    
    // Get the screen size based on the core's aspect size
    private func getScreenSize() -> CGSize {
        // Use the core's aspectSize property
        return coreInstance.aspectSize
    }
    
    // Load control layout data from the system
    private func loadControlLayoutData() {
        guard let systemId = systemId else { return }
        
        // Access Realm to get the system
        do {
            let realm = try Realm()
            if let system = realm.object(ofType: PVSystem.self, forPrimaryKey: systemId.rawValue) {
                self.controlLayout = system.controllerLayout
            }
        } catch {
            print("Error accessing Realm: \(error)")
        }
    }
    
    // Dynamic controller skin based on system's control layout
    private var dynamicControllerSkin: AnyView {
        // If we have control layout data, use it to build a dynamic skin
        if let controlLayout = controlLayout {
            AnyView(buildDynamicSkin(from: controlLayout))
        } else {
            // Fallback to the generic skin if no control layout data is available
            AnyView(buildGenericSkin())
        }
    }
    
    // Dynamic landscape controller skin
    private var dynamicLandscapeControllerSkin: AnyView {
        // If we have control layout data, use it to build a dynamic skin for landscape
        if let controlLayout = controlLayout {
            AnyView(buildDynamicLandscapeSkin(from: controlLayout))
        } else {
            // Fallback to the generic landscape skin if no control layout data is available
            AnyView(landscapeControllerLayout)
        }
    }
    
    // Generic skin when no control layout data is available
    @ViewBuilder
    private func buildGenericSkin() -> some View {
        VStack(spacing: 15) {
            // Top row - L/R buttons and menu/turbo
            HStack(spacing: 15) {
                // L buttons
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        shoulderButton(label: "L", color: .gray)
                        shoulderButton(label: "L2", color: .gray)
                    }
                    shoulderButton(label: "L3", color: .gray)
                }
                
                Spacer()
                
                // Menu and Turbo buttons - horizontally aligned
                HStack(spacing: 15) {
                    utilityButton(label: "MENU", color: .purple, systemImage: "line.3.horizontal")
                    utilityButton(label: "TURBO", color: .orange, systemImage: "forward.fill")
                }
                
                Spacer()
                
                // R buttons
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        shoulderButton(label: "R", color: .gray)
                        shoulderButton(label: "R2", color: .gray)
                    }
                    shoulderButton(label: "R3", color: .gray)
                }
            }
            .padding(.horizontal)
            
            Spacer().frame(height: 20) // Add space to raise D-pad position
            
            HStack(spacing: 30) { // Increased spacing between D-pad and action buttons
                // Left side - D-Pad or Joystick
                VStack(spacing: 5) {
                    // D-pad/Joystick toggle
                    Button(action: {
                        // Toggle the internal state which we can modify
                        useJoystickInternal.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: useJoystickInternal ? "circle.grid.cross" : "dpad")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                            
                            Text(useJoystickInternal ? "JOYSTICK" : "D-PAD")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.blue.opacity(0.7))
                        .cornerRadius(10)
                    }
                    .buttonStyle(GameButtonStyle(pressAction: {
                        inputHandler.buttonPressed("toggle")
                    }, releaseAction: {
                        inputHandler.buttonReleased("toggle")
                    }))
                    
                    // Show either D-pad or joystick based on toggle
                    if useJoystickInternal {
                        joystickView()
                    } else {
                        dPadView()
                    }
                }
                
                Spacer() // Push action buttons to the right
                
                // Right side - Action buttons (right-aligned) with increased spacing
                VStack(spacing: 20) { // Increased vertical spacing
                    HStack(spacing: 30) { // Significantly increased horizontal spacing
                        VStack(spacing: 25) { // Increased vertical spacing between Y and X
                            circleButton(label: "Y", color: .yellow)
                            circleButton(label: "X", color: .blue)
                        }
                        
                        VStack(spacing: 25) { // Increased vertical spacing between B and A
                            circleButton(label: "B", color: .red)
                            circleButton(label: "A", color: .green)
                        }
                    }
                }
            }
            
            Spacer().frame(height: 20) // Add space before Start/Select buttons
            
            // Start/Select buttons centered at the bottom
            HStack {
                Spacer() // Center the buttons
                HStack(spacing: 30) { // Increased spacing between buttons
                    pillButton(label: "SELECT", color: .black)
                    pillButton(label: "START", color: .black)
                }
                Spacer() // Center the buttons
            }
        }
        .padding()
    }
    
    /// Stylized D-Pad view with retrowave aesthetic
    /// Custom octagon shape with rounded corners
    private struct RoundedOctagon: Shape {
        var cornerRadius: CGFloat
        
        func path(in rect: CGRect) -> Path {
            let width = rect.width
            let height = rect.height
            let radius = min(width, height) / 2
            let center = CGPoint(x: rect.midX, y: rect.midY)
            
            // Calculate the eight points of the octagon
            var points: [CGPoint] = []
            for i in 0..<8 {
                let angle = CGFloat(i) * .pi / 4
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                points.append(CGPoint(x: x, y: y))
            }
            
            // Create a path with rounded corners
            var path = Path()
            for (index, point) in points.enumerated() {
                let nextIndex = (index + 1) % points.count
                let nextPoint = points[nextIndex]
                
                if index == 0 {
                    path.move(to: point)
                }
                
                path.addLine(to: nextPoint)
            }
            
            return path
        }
    }
    
    // Track active D-pad directions and touch position
    private class DPadState: ObservableObject {
        @Published var up = false
        @Published var down = false
        @Published var left = false
        @Published var right = false
        @Published var touchPosition: CGPoint = .zero
        @Published var isTouching = false
        
        func reset() {
            up = false
            down = false
            left = false
            right = false
            isTouching = false
        }
    }
    
    private func dPadView() -> some View {
        // Create a state object to track active directions
        let dpadState = DPadState()
        
        return ZStack {
            // D-pad background with neon glow using octagon shape
            RoundedOctagon(cornerRadius: 15)
                .fill(Color.black.opacity(0.7))
                .frame(width: 180, height: 180)
                .overlay(
                    RoundedOctagon(cornerRadius: 15)
                        .stroke(Color(red: 0.99, green: 0.11, blue: 0.55, opacity: 0.8), lineWidth: 2)
                        .blur(radius: 4)
                )
                .overlay(
                    RoundedOctagon(cornerRadius: 15)
                        .stroke(Color.white, lineWidth: 1)
                )
            
            // D-pad cross indicator (plus shape)
            ZStack {
                // Horizontal line
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 120, height: 2)
                
                // Vertical line
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 2, height: 120)
            }
            
            // Directional indicators that highlight when active
            ZStack {
                // Up indicator
                Text("▲")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(dpadState.up ? Color(red: 0.99, green: 0.11, blue: 0.55) : .white)
                    .shadow(color: Color(red: 0.99, green: 0.11, blue: 0.55), radius: dpadState.up ? 6 : 2)
                    .position(x: 90, y: 45)
                
                // Down indicator
                Text("▼")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(dpadState.down ? Color(red: 0.99, green: 0.11, blue: 0.55) : .white)
                    .shadow(color: Color(red: 0.99, green: 0.11, blue: 0.55), radius: dpadState.down ? 6 : 2)
                    .position(x: 90, y: 135)
                
                // Left indicator
                Text("◀")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(dpadState.left ? Color(red: 0.99, green: 0.11, blue: 0.55) : .white)
                    .shadow(color: Color(red: 0.99, green: 0.11, blue: 0.55), radius: dpadState.left ? 6 : 2)
                    .position(x: 45, y: 90)
                
                // Right indicator
                Text("▶")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(dpadState.right ? Color(red: 0.99, green: 0.11, blue: 0.55) : .white)
                    .shadow(color: Color(red: 0.99, green: 0.11, blue: 0.55), radius: dpadState.right ? 6 : 2)
                    .position(x: 135, y: 90)
            }
            
            // Touch indicator overlay - positioned above the gesture area but below the gesture recognizer
            if dpadState.isTouching {
                DeltaSkinTouchIndicator(at: dpadState.touchPosition)
                    .allowsHitTesting(false) // Prevent the indicator from interfering with touches
            }
            
            // Gesture area
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Calculate position relative to center
                            let center = CGPoint(x: 90, y: 90)
                            let location = value.location
                            let dx = location.x - center.x
                            let dy = location.y - center.y
                            
                            // Update touch position for the indicator
                            dpadState.touchPosition = location
                            dpadState.isTouching = true
                            
                            // Determine which directions should be active
                            let newUp = dy < -20
                            let newDown = dy > 20
                            let newLeft = dx < -20
                            let newRight = dx > 20
                            
                            // Handle direction changes
                            if newUp != dpadState.up {
                                dpadState.up = newUp
                                if newUp {
                                    inputHandler.buttonPressed("up")
                                } else {
                                    inputHandler.buttonReleased("up")
                                }
                            }
                            
                            if newDown != dpadState.down {
                                dpadState.down = newDown
                                if newDown {
                                    inputHandler.buttonPressed("down")
                                } else {
                                    inputHandler.buttonReleased("down")
                                }
                            }
                            
                            if newLeft != dpadState.left {
                                dpadState.left = newLeft
                                if newLeft {
                                    inputHandler.buttonPressed("left")
                                } else {
                                    inputHandler.buttonReleased("left")
                                }
                            }
                            
                            if newRight != dpadState.right {
                                dpadState.right = newRight
                                if newRight {
                                    inputHandler.buttonPressed("right")
                                } else {
                                    inputHandler.buttonReleased("right")
                                }
                            }
                        }
                        .onEnded { _ in
                            // Release all directions when touch ends
                            if dpadState.up {
                                inputHandler.buttonReleased("up")
                            }
                            if dpadState.down {
                                inputHandler.buttonReleased("down")
                            }
                            if dpadState.left {
                                inputHandler.buttonReleased("left")
                            }
                            if dpadState.right {
                                inputHandler.buttonReleased("right")
                            }
                            dpadState.reset()
                        }
                )
        }
        .frame(width: 150, height: 150)
    }
    
    /// Joystick view
    private func joystickView() -> some View {
        // State for joystick position
        GeometryReader { geometry in
            ZStack {
                // Joystick background
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: geometry.size.width, height: geometry.size.width)
                
                // Joystick handle
                Circle()
                    .fill(Color.gray)
                    .frame(width: geometry.size.width * 0.4, height: geometry.size.width * 0.4)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Calculate position relative to center
                                let center = CGPoint(x: geometry.size.width/2, y: geometry.size.width/2)
                                let location = value.location
                                
                                // Calculate distance from center
                                let deltaX = location.x - center.x
                                let deltaY = location.y - center.y
                                
                                // Calculate distance and angle
                                let distance = sqrt(deltaX*deltaX + deltaY*deltaY)
                                
                                // Normalize to -1.0 to 1.0 range
                                let maxDistance = geometry.size.width/2 * 0.8
                                let normalizedX = Float(min(max(deltaX / maxDistance, -1.0), 1.0))
                                let normalizedY = Float(min(max(-deltaY / maxDistance, -1.0), 1.0)) // Invert Y for proper direction
                                
                                // Send to input handler
                                inputHandler.analogStickMoved("leftAnalog", x: normalizedX, y: normalizedY)
                            }
                            .onEnded { _ in
                                // Reset to center position
                                inputHandler.analogStickMoved("leftAnalog", x: 0, y: 0)
                            }
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(width: 120, height: 120)
    }
    
    /// Circle button view with retrowave styling
    private func circleButton(label: String, color: Color) -> some View {
        Button(action: {}) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.clear)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: 2)
                            .blur(radius: 4)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1)
                    )
                
                // Button label with neon effect
                NeonText(label, color: color, fontSize: 20)
            }
            .frame(width: 60, height: 60)
        }
        .buttonStyle(GameButtonStyle(pressAction: {
            inputHandler.buttonPressed(label.lowercased())
        }, releaseAction: {
            inputHandler.buttonReleased(label.lowercased())
        }))
    }
    
    /// Pill-shaped button view with retrowave styling
    private func pillButton(label: String, color: Color) -> some View {
        Button(action: {}) {
            ZStack {
                // Outer glow
                Capsule()
                    .fill(Color.clear)
                    .frame(width: 80, height: 35)
                    .overlay(
                        Capsule()
                            .stroke(Color(red: 0.99, green: 0.11, blue: 0.55, opacity: 0.8), lineWidth: 2)
                            .blur(radius: 4)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white, lineWidth: 1)
                    )
                
                // Button label with neon effect
                NeonText(label, color: Color(red: 0.99, green: 0.11, blue: 0.55), fontSize: 14)
            }
            .frame(width: 80, height: 35)
        }
        .buttonStyle(GameButtonStyle(pressAction: {
            inputHandler.buttonPressed(label.lowercased())
        }, releaseAction: {
            inputHandler.buttonReleased(label.lowercased())
        }))
    }
    
    /// Shoulder button view with retrowave styling
    private func shoulderButton(label: String, color: Color) -> some View {
        Button(action: {}) {
            ZStack {
                // Outer glow
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
                    .frame(width: 45, height: 35)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(red: 0.0, green: 0.8, blue: 0.9, opacity: 0.8), lineWidth: 2)
                            .blur(radius: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white, lineWidth: 1)
                    )
                
                // Button label with neon effect
                NeonText(label, color: Color(red: 0.0, green: 0.8, blue: 0.9), fontSize: 14)
            }
            .frame(width: 45, height: 35)
        }
        .buttonStyle(GameButtonStyle(pressAction: {
            inputHandler.buttonPressed(label.lowercased())
        }, releaseAction: {
            inputHandler.buttonReleased(label.lowercased())
        }))
    }
    
    /// Utility button with icon and retrowave styling
    private func utilityButton(label: String, color: Color, systemImage: String) -> some View {
        Button(action: {}) {
            ZStack {
                // Outer glow
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
                    .frame(width: 60, height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color, lineWidth: 2)
                            .blur(radius: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white, lineWidth: 1)
                    )
                
                // Button content with neon effect
                VStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .shadow(color: color, radius: 2)
                        .shadow(color: color, radius: 4)
                    
                    NeonText(label, color: color, fontSize: 12)
                }
            }
            .frame(width: 60, height: 50)
        }
        .buttonStyle(GameButtonStyle(pressAction: {
            inputHandler.buttonPressed(label.lowercased())
        }, releaseAction: {
            inputHandler.buttonReleased(label.lowercased())
        }))
    }
    
    // Build a dynamic landscape skin based on the system's control layout data
    @ViewBuilder
    private func buildDynamicLandscapeSkin(from layout: [ControlLayoutEntry]) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Top row with shoulder buttons, menu and turbo buttons
                VStack {
                    HStack {
                        // Left shoulder buttons
                        HStack(spacing: 15) {
                            if hasControl(type: "PVLeftShoulderButton", title: "L", in: layout) {
                                shoulderButton(label: "L", color: .gray)
                            }
                            if hasControl(type: "PVLeftShoulderButton", title: "L2", in: layout) {
                                shoulderButton(label: "L2", color: .gray)
                            }
                            if hasControl(type: "PVLeftAnalogButton", title: "L3", in: layout) {
                                shoulderButton(label: "L3", color: .gray)
                            }
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        // Menu and Turbo buttons in center
                        HStack(spacing: 20) {
                            utilityButton(label: "MENU", color: .purple, systemImage: "line.3.horizontal")
                            utilityButton(label: "TURBO", color: .orange, systemImage: "forward.fill")
                        }
                        
                        Spacer()
                        
                        // Right shoulder buttons
                        HStack(spacing: 15) {
                            if hasControl(type: "PVRightAnalogButton", title: "R3", in: layout) {
                                shoulderButton(label: "R3", color: .gray)
                            }
                            if hasControl(type: "PVRightShoulderButton", title: "R2", in: layout) {
                                shoulderButton(label: "R2", color: .gray)
                            }
                            if hasControl(type: "PVRightShoulderButton", title: "R", in: layout) {
                                shoulderButton(label: "R", color: .gray)
                            }
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Start/Select buttons at the center bottom
                    HStack {
                        Spacer()
                        
                        HStack(spacing: 30) {
                            if hasControl(type: "PVSelectButton", in: layout) {
                                pillButton(label: "SELECT", color: .black)
                            }
                            if hasControl(type: "PVStartButton", in: layout) {
                                pillButton(label: "START", color: .black)
                            }
                        }
                        .padding(.bottom, 20)
                        
                        Spacer()
                    }
                }
                
                // D-pad positioned at left edge
                VStack {
                    Spacer()
                    HStack {
                        if useJoystickInternal && hasControl(type: "PVJoyPad", in: layout) {
                            joystickView()
                        } else if hasControl(type: "PVDPad", in: layout) {
                            dPadView()
                        }
                        Spacer()
                    }
                    .padding(.leading, 80)
                    Spacer()
                }
                .frame(width: geometry.size.width, alignment: .leading)
                
                // Action buttons positioned at right edge using absolute positioning
                VStack {
                    Spacer()
                    // Find all button groups in the layout
                    let buttonGroups = layout.filter { $0.PVControlType == "PVButtonGroup" }
                    
                    if !buttonGroups.isEmpty {
                        // If we have button groups, display them in a VStack
                        VStack(spacing: 20) {
                            ForEach(0..<buttonGroups.count, id: \.self) { index in
                                if let groupedButtons = buttonGroups[index].PVGroupedButtons {
                                    // Create a grid of buttons for each button group
                                    createButtonGroup(from: groupedButtons)
                                }
                            }
                        }
                    } else {
                        // Fallback to generic ABXY layout with improved spacing
                        HStack(spacing: 30) {
                            VStack(spacing: 25) {
                                circleButton(label: "Y", color: .yellow)
                                circleButton(label: "X", color: .blue)
                            }
                            
                            VStack(spacing: 25) {
                                circleButton(label: "B", color: .red)
                                circleButton(label: "A", color: .green)
                            }
                        }
                    }
                    Spacer()
                }
                .frame(width: 250) // Increased width to accommodate multiple button groups
                .position(x: geometry.size.width - 150, y: geometry.size.height / 2)
            }
        }
    }
    
    // Build a dynamic skin based on the system's control layout data
    @ViewBuilder
    private func buildDynamicSkin(from layout: [ControlLayoutEntry]) -> some View {
        VStack(spacing: 15) {
            // Top row - utility buttons and system-specific shoulder buttons
            HStack(spacing: 15) {
                // L buttons
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        // Check if L1/L buttons are in the layout
                        if hasControl(type: "PVLeftShoulderButton", title: "L1", in: layout) ||
                            hasControl(type: "PVLeftShoulderButton", title: "L", in: layout) {
                            shoulderButton(label: "L", color: .gray)
                        }
                        // Check if L2 buttons are in the layout
                        if hasControl(type: "PVLeftShoulderButton", title: "L2", in: layout) {
                            shoulderButton(label: "L2", color: .gray)
                        }
                    }
                    // Check if L3 buttons are in the layout
                    if hasControl(type: "PVLeftAnalogButton", title: "L3", in: layout) {
                        shoulderButton(label: "L3", color: .gray)
                    }
                }
                
                Spacer()
                
                // Menu and Turbo buttons - horizontally aligned
                HStack(spacing: 15) {
                    utilityButton(label: "MENU", color: .purple, systemImage: "line.3.horizontal")
                    utilityButton(label: "TURBO", color: .orange, systemImage: "forward.fill")
                }
                
                Spacer()
                
                // R buttons
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        // Check if R1/R buttons are in the layout
                        if hasControl(type: "PVRightShoulderButton", title: "R1", in: layout) ||
                            hasControl(type: "PVRightShoulderButton", title: "R", in: layout) {
                            shoulderButton(label: "R", color: .gray)
                        }
                        // Check if R2 buttons are in the layout
                        if hasControl(type: "PVRightShoulderButton", title: "R2", in: layout) {
                            shoulderButton(label: "R2", color: .gray)
                        }
                    }
                    // Check if R3 buttons are in the layout
                    if hasControl(type: "PVRightAnalogButton", title: "R3", in: layout) {
                        shoulderButton(label: "R3", color: .gray)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer().frame(height: 20) // Add space to raise D-pad position
            
            HStack(spacing: 30) { // Increased spacing between D-pad and action buttons
                // Left side - D-Pad or Joystick
                VStack(spacing: 5) {
                    // Only show D-pad/joystick toggle if the system has both
                    if hasControl(type: "PVDPad", in: layout) && hasControl(type: "PVJoyPad", in: layout) {
                        Button(action: {
                            useJoystickInternal.toggle()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: useJoystickInternal ? "circle.grid.cross" : "dpad")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                
                                Text(useJoystickInternal ? "JOYSTICK" : "D-PAD")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.blue.opacity(0.7))
                            .cornerRadius(10)
                        }
                        .buttonStyle(GameButtonStyle(pressAction: {
                            inputHandler.buttonPressed("up")
                        }, releaseAction: {
                            inputHandler.buttonReleased("up")
                        }))
                    }
                    
                    // Show either D-pad or joystick based on toggle and system support
                    if useJoystickInternal && hasControl(type: "PVJoyPad", in: layout) {
                        joystickView()
                    } else if hasControl(type: "PVDPad", in: layout) {
                        dPadView()
                    }
                }
                
                Spacer() // Push action buttons to the right
                
                // Right side - Action buttons (right-aligned)
                VStack(spacing: 10) {
                    // Find all button groups in the layout
                    let buttonGroups = layout.filter { $0.PVControlType == "PVButtonGroup" }
                    
                    if !buttonGroups.isEmpty {
                        // If we have button groups, display them in a VStack
                        VStack(spacing: 20) {
                            ForEach(0..<buttonGroups.count, id: \.self) { index in
                                if let groupedButtons = buttonGroups[index].PVGroupedButtons {
                                    // Create a grid of buttons for each button group
                                    HStack {
                                        Spacer() // Push buttons to the right
                                        createButtonGroup(from: groupedButtons)
                                            .id("buttonGroup_\(index)") // Add unique ID to force redraw
                                    }
                                }
                            }
                        }
                    } else {
                        // Fallback to generic ABXY layout with improved spacing
                        HStack {
                            Spacer() // Push buttons to the right
                            HStack(spacing: 30) { // Significantly increased horizontal spacing
                                VStack(spacing: 25) { // Increased vertical spacing between Y and X
                                    circleButton(label: "Y", color: .yellow)
                                    circleButton(label: "X", color: .blue)
                                }
                                
                                VStack(spacing: 25) { // Increased vertical spacing between B and A
                                    circleButton(label: "B", color: .red)
                                    circleButton(label: "A", color: .green)
                                }
                            }
                        }
                    }
                }
            }
            
            Spacer().frame(height: 20) // Add space before Start/Select buttons
            
            // Start/Select buttons centered at the bottom
            HStack {
                Spacer() // Center the buttons
                HStack(spacing: 30) { // Increased spacing between buttons
                    if hasControl(type: "PVSelectButton", in: layout) {
                        pillButton(label: "SELECT", color: .black)
                    }
                    if hasControl(type: "PVStartButton", in: layout) {
                        pillButton(label: "START", color: .black)
                    }
                }
                Spacer() // Center the buttons
            }
        }
        .padding()
    }
    
    // Create a button group based on the system's button layout
    private func createButtonGroup(from buttons: [ControlGroupButton]) -> some View {
        // Determine the best layout based on button count
        if buttons.count == 4 {
            // Standard 2x2 grid for 4 buttons
            return AnyView(
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        createButton(from: buttons[0])
                            .id("button_group_0_\(buttons[0].PVControlTitle ?? "unknown")")
                        createButton(from: buttons[1])
                            .id("button_group_0_\(buttons[1].PVControlTitle ?? "unknown")")
                    }
                    HStack(spacing: 10) {
                        createButton(from: buttons[2])
                            .id("button_group_0_\(buttons[2].PVControlTitle ?? "unknown")")
                        createButton(from: buttons[3])
                            .id("button_group_0_\(buttons[3].PVControlTitle ?? "unknown")")
                    }
                }
            )
        } else if buttons.count == 3 {
            // Triangle arrangement for 3 buttons (like Jaguar ABC)
            return AnyView(
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        createButton(from: buttons[0])
                            .id("button_group_1_\(buttons[0].PVControlTitle ?? "unknown")")
                    }
                    HStack(spacing: 10) {
                        createButton(from: buttons[1])
                            .id("button_group_1_\(buttons[1].PVControlTitle ?? "unknown")")
                        createButton(from: buttons[2])
                            .id("button_group_1_\(buttons[2].PVControlTitle ?? "unknown")")
                    }
                }
            )
        } else if buttons.count >= 9 && buttons.count <= 12 {
            // Number pad layout (3x4 grid for 9-12 buttons)
            return AnyView(
                VStack(spacing: 10) {
                    // First row
                    HStack(spacing: 10) {
                        ForEach(0..<min(3, buttons.count), id: \.self) { index in
                            createButton(from: buttons[index])
                        }
                    }
                    // Second row
                    if buttons.count > 3 {
                        HStack(spacing: 10) {
                            ForEach(3..<min(6, buttons.count), id: \.self) { index in
                                createButton(from: buttons[index])
                            }
                        }
                    }
                    // Third row
                    if buttons.count > 6 {
                        HStack(spacing: 10) {
                            ForEach(6..<min(9, buttons.count), id: \.self) { index in
                                createButton(from: buttons[index])
                            }
                        }
                    }
                    // Fourth row
                    if buttons.count > 9 {
                        HStack(spacing: 10) {
                            ForEach(9..<min(12, buttons.count), id: \.self) { index in
                                createButton(from: buttons[index])
                            }
                        }
                    }
                }
            )
        } else {
            // Fallback for other button counts
            return AnyView(
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 10) {
                    ForEach(0..<buttons.count, id: \.self) { index in
                        createButton(from: buttons[index])
                    }
                }
            )
        }
    }
    
    // Create a button from a ControlGroupButton
    private func createButton(from button: ControlGroupButton) -> some View {
        let displayLabel = button.PVControlTitle ?? "Button"
        
        // Map special PlayStation symbols to their proper identifiers
        let actionIdentifier = button.PVControlTitle ?? displayLabel
        
        let color = colorFromString(button.PVControlTint) ?? .gray
        
        return Button(action: {}) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.clear)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: 2)
                            .blur(radius: 4)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1)
                    )
                
                // Button label with neon effect
                NeonText(displayLabel, color: color, fontSize: 20)
            }
            .frame(width: 60, height: 60)
        }
        .buttonStyle(GameButtonStyle(pressAction: {
            // Log button press for debugging
            print("Button pressed: \(actionIdentifier)")
            inputHandler.buttonPressed(actionIdentifier)
        }, releaseAction: {
            // Log button release for debugging
            print("Button released: \(actionIdentifier)")
            inputHandler.buttonReleased(actionIdentifier)
        }))
        .id("button_\(actionIdentifier)_\(UUID().uuidString)") // Ensure each button has a unique ID
    }
    
    // Custom button style that handles press and release events
    struct GameButtonStyle: ButtonStyle {
        let pressAction: () -> Void
        let releaseAction: () -> Void
        
        @State private var isShowingOverlay = false
        @State private var touchPosition: CGPoint = CGPoint(x: 30, y: 30)
        
        func makeBody(configuration: Configuration) -> some View {
            ZStack {
                // The button itself
                configuration.label
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
                    .overlay(
                        // Touch overlay that appears when pressed - positioned as an overlay to avoid layout issues
                        Group {
                            if configuration.isPressed || isShowingOverlay {
                                DeltaSkinTouchIndicator(at: touchPosition)
                                    .allowsHitTesting(false) // Prevent the indicator from interfering with touches
                            }
                        }
                    )
            }
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    withAnimation(.easeIn(duration: 0.1)) {
                        isShowingOverlay = true
                    }
                    pressAction()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isShowingOverlay = false
                    }
                    releaseAction()
                }
            }
        }
    }
    
    // Convert a color string to a Color
    private func colorFromString(_ colorString: String?) -> Color? {
        guard let hexString = colorString else { return nil }
        
        // Remove the # prefix if present
        var hex = hexString
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }
        
        // Parse the hex color
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
    
    // Check if a specific control type exists in the layout
    private func hasControl(type: String, in layout: [ControlLayoutEntry]) -> Bool {
        return layout.contains(where: { $0.PVControlType == type })
    }
    
    // Check if a specific control type with a specific title exists in the layout
    private func hasControl(type: String, title: String, in layout: [ControlLayoutEntry]) -> Bool {
        return layout.contains(where: { $0.PVControlType == type && $0.PVControlTitle == title })
    }
}
