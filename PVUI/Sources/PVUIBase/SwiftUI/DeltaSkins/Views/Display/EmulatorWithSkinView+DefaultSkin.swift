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

// MARK: - Default Controller
extension EmulatorWithSkinView {
    
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
        VStack {
            Spacer() // Push the controller to the bottom of the screen
            
            dynamicControllerSkin
                .onAppear {
                    loadControlLayoutData()
                }
        }
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
    
    // Generic skin when no control layout data is available
    @ViewBuilder
    private func buildGenericSkin() -> some View {
        VStack(spacing: 15) {
            // Top row - L/R buttons and menu
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
                
                // Menu and Fast Forward
                VStack(spacing: 5) {
                    utilityButton(label: "MENU", color: .purple, systemImage: "line.3.horizontal")
                    utilityButton(label: "FF", color: .orange, systemImage: "forward.fill")
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
            
            HStack(spacing: 20) {
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
                    .buttonStyle(PlainButtonStyle())
                    
                    // Show either D-pad or joystick based on toggle
                    if useJoystickInternal {
                        joystickView()
                    } else {
                        dPadView()
                    }
                }
                
                // Right side - Action buttons
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        VStack(spacing: 10) {
                            circleButton(label: "Y", color: .yellow)
                            circleButton(label: "X", color: .blue)
                        }
                        
                        VStack(spacing: 10) {
                            circleButton(label: "B", color: .red)
                            circleButton(label: "A", color: .green)
                        }
                    }
                    
                    // Start/Select buttons
                    HStack(spacing: 20) {
                        pillButton(label: "SELECT", color: .black)
                        pillButton(label: "START", color: .black)
                    }
                }
            }
        }
        .padding()
    }
    
    /// D-Pad view
    private func dPadView() -> some View {
        VStack(spacing: 0) {
            Button(action: { inputHandler.buttonPressed("up") }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in inputHandler.buttonReleased("up") }
            )
            
            HStack(spacing: 0) {
                Button(action: { inputHandler.buttonPressed("left") }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in inputHandler.buttonReleased("left") }
                )
                
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
                
                Button(action: { inputHandler.buttonPressed("right") }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in inputHandler.buttonReleased("right") }
                )
            }
            
            Button(action: { inputHandler.buttonPressed("down") }) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in inputHandler.buttonReleased("down") }
            )
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(15)
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
    
    /// Circle button view
    private func circleButton(label: String, color: Color) -> some View {
        Button(action: { inputHandler.buttonPressed(label.lowercased()) }) {
            Text(label)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .clipShape(Circle())
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in inputHandler.buttonReleased(label.lowercased()) }
        )
    }
    
    /// Pill-shaped button view
    private func pillButton(label: String, color: Color) -> some View {
        Button(action: { inputHandler.buttonPressed(label.lowercased()) }) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 30)
                .background(color)
                .cornerRadius(15)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in inputHandler.buttonReleased(label.lowercased()) }
        )
    }
    
    /// Shoulder button view
    private func shoulderButton(label: String, color: Color) -> some View {
        Button(action: { inputHandler.buttonPressed(label.lowercased()) }) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 25)
                .background(color)
                .cornerRadius(8)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in inputHandler.buttonReleased(label.lowercased()) }
        )
    }
    
    /// Utility button with icon
    private func utilityButton(label: String, color: Color, systemImage: String) -> some View {
        Button(action: { inputHandler.buttonPressed(label.lowercased()) }) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 50, height: 40)
            .background(color)
            .cornerRadius(8)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in inputHandler.buttonReleased(label.lowercased()) }
        )
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
                
                // Menu and Fast Forward (always include these utility buttons)
                VStack(spacing: 5) {
                    utilityButton(label: "MENU", color: .purple, systemImage: "line.3.horizontal")
                    utilityButton(label: "FF", color: .orange, systemImage: "forward.fill")
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
            
            HStack(spacing: 20) {
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
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Show either D-pad or joystick based on toggle and system support
                    if useJoystickInternal && hasControl(type: "PVJoyPad", in: layout) {
                        joystickView()
                    } else if hasControl(type: "PVDPad", in: layout) {
                        dPadView()
                    }
                }
                
                // Right side - Action buttons and menu buttons
                VStack(spacing: 10) {
                    // Check if the system has a button group (action buttons)
                    if let buttonGroup = layout.first(where: { $0.PVControlType == "PVButtonGroup" }),
                       let groupedButtons = buttonGroup.PVGroupedButtons {
                        // Create a grid of buttons based on the system's button group
                        createButtonGroup(from: groupedButtons)
                    } else {
                        // Fallback to generic ABXY layout
                        HStack(spacing: 10) {
                            VStack(spacing: 10) {
                                circleButton(label: "Y", color: .yellow)
                                circleButton(label: "X", color: .blue)
                            }
                            
                            VStack(spacing: 10) {
                                circleButton(label: "B", color: .red)
                                circleButton(label: "A", color: .green)
                            }
                        }
                    }
                    
                    // Start/Select buttons if present in the layout
                    HStack(spacing: 20) {
                        if hasControl(type: "PVSelectButton", in: layout) {
                            pillButton(label: "SELECT", color: .black)
                        }
                        if hasControl(type: "PVStartButton", in: layout) {
                            pillButton(label: "START", color: .black)
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    // Create a button group based on the system's button layout
    private func createButtonGroup(from buttons: [ControlGroupButton]) -> some View {
        // Determine if we should use a 2x2 grid or another arrangement
        if buttons.count == 4 {
            // Standard 2x2 grid for 4 buttons
            return AnyView(
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        createButton(from: buttons[0])
                        createButton(from: buttons[1])
                    }
                    HStack(spacing: 10) {
                        createButton(from: buttons[2])
                        createButton(from: buttons[3])
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
        let label = button.PVControlTitle
        let color = colorFromString(button.PVControlTint) ?? .gray
        
        return circleButton(label: label, color: color)
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
