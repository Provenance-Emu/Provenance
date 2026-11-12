//
//  ControllerInputTestView.swift
//  PVUI
//
//  Shows what each connected controller reports right now: touchpad fingers and click,
//  motion sensors, and the names of its inputs. It exists to check on real hardware the
//  things the touchpad and gyro features assume.
//

import SwiftUI
import GameController
import PVCoreBridge
import PVUIBase

struct ControllerInputTestView: View {
    /// How often the readings refresh.
    private static let refreshInterval: TimeInterval = 1.0 / 30

    /// Sensors this screen switched on, so it can switch them off again when it closes.
    @State private var activatedSensors: [ObjectIdentifier: GCMotion] = [:]

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.refreshInterval)) { _ in
            List {
                let controllers = GCController.controllers()
                if controllers.isEmpty {
                    Section {
                        ControllerInputTestRow(title: "No controller connected", value: "")
                    }
                }
                ForEach(controllers, id: \.self) { controller in
                    ControllerInputTestSection(controller: controller)
                }
                Section {
                    EmptyView()
                } footer: {
                    Text("Motion sensors are switched on while this screen is open. On Apple TV, B and Menu still leave it.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Controller Input Test")
        .onAppear(perform: activateSensors)
        .onDisappear(perform: restoreSensors)
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { _ in activateSensors() }
        .settingsSubpageTracking()
    }

    /// Pads such as the DualSense report no motion until their sensors are switched on.
    private func activateSensors() {
        for controller in GCController.controllers() {
            guard let motion = controller.motion, motion.sensorsRequireManualActivation, !motion.sensorsActive else { continue }
            motion.sensorsActive = true
            activatedSensors[ObjectIdentifier(motion)] = motion
        }
    }

    private func restoreSensors() {
        for motion in activatedSensors.values {
            motion.sensorsActive = false
        }
        activatedSensors.removeAll()
    }
}

// MARK: - One controller

private struct ControllerInputTestSection: View {
    let controller: GCController

    var body: some View {
        Section {
            ControllerInputTestRow(title: "Category", value: controller.productCategory)
            touchpadRows
            motionRows
            elementRows
        } header: {
            Text(controller.vendorName ?? "Controller")
        }
    }

    @ViewBuilder
    private var touchpadRows: some View {
        if let sample = controller.touchpadSample {
            TouchpadDiagram(sample: sample)
            ControllerInputTestRow(title: "Finger 1", value: Self.describe(sample.primary))
            ControllerInputTestRow(title: "Finger 2", value: Self.describe(sample.secondary))
            ControllerInputTestRow(title: "Touchpad click", value: sample.isClicked ? "Pressed" : "Up")
        } else {
            ControllerInputTestRow(title: "Touchpad", value: "None")
        }
    }

    @ViewBuilder
    private var motionRows: some View {
        if let motion = controller.motion {
            ControllerInputTestRow(
                title: "Sensors", value: motion.sensorsRequireManualActivation
                    ? (motion.sensorsActive ? "Manual, on" : "Manual, off") : "Always on")
            ControllerInputTestRow(title: "Reports", value: Self.capabilities(of: motion))
            ControllerInputTestRow(
                title: "Rotation rate", value: Self.vector(motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z))
            ControllerInputTestRow(
                title: "Acceleration", value: Self.vector(motion.acceleration.x, motion.acceleration.y, motion.acceleration.z))
            if motion.hasGravityAndUserAcceleration {
                ControllerInputTestRow(title: "Gravity", value: Self.vector(motion.gravity.x, motion.gravity.y, motion.gravity.z))
            }
        } else {
            ControllerInputTestRow(title: "Motion", value: "None")
        }
    }

    @ViewBuilder
    private var elementRows: some View {
        let buttons = controller.physicalInputProfile.buttons
        let pressed = buttons.filter { $0.value.isPressed }.keys.sorted()
        ControllerInputTestRow(title: "Pressed", value: pressed.isEmpty ? "Nothing" : pressed.joined(separator: ", "))
        ControllerInputTestRow(title: "Inputs (\(buttons.count))", value: buttons.keys.sorted().joined(separator: ", "))
    }

    private static func describe(_ point: TouchpadPoint?) -> String {
        guard let point else { return "Up (0, 0)" }
        return String(format: "x %+.2f  y %+.2f", point.x, point.y)
    }

    private static func vector(_ x: Double, _ y: Double, _ z: Double) -> String {
        String(format: "x %+.2f  y %+.2f  z %+.2f", x, y, z)
    }

    private static func capabilities(of motion: GCMotion) -> String {
        var parts: [String] = []
        if motion.hasRotationRate { parts.append("rotation rate") }
        if motion.hasGravityAndUserAcceleration { parts.append("gravity + user acceleration") }
        if motion.hasAttitude { parts.append("attitude") }
        return parts.isEmpty ? "acceleration only" : parts.joined(separator: ", ")
    }
}

// MARK: - Pieces

/// A label and a reading. Focusable on tvOS so the list can be scrolled with a remote.
private struct ControllerInputTestRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            if !value.isEmpty {
                Text(value)
                    .font(.body.monospacedDigit())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #if os(tvOS)
        .focusable()
        #endif
    }
}

/// The touchpad drawn as a box with a dot for each finger.
private struct TouchpadDiagram: View {
    private static let aspectRatio: CGFloat = 2.2
    private static let dotDiameter: CGFloat = 18
    private static let maxWidth: CGFloat = 360

    let sample: TouchpadSample

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(sample.isClicked ? Color.accentColor : Color.secondary, lineWidth: sample.isClicked ? 3 : 1)
                dot(for: sample.primary, color: .accentColor, in: proxy.size)
                dot(for: sample.secondary, color: .orange, in: proxy.size)
            }
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .frame(maxWidth: Self.maxWidth)
        .accessibilityLabel("Touchpad")
    }

    @ViewBuilder
    private func dot(for point: TouchpadPoint?, color: Color, in size: CGSize) -> some View {
        if let point {
            /// Pad units run -1...1 with +y up; the drawing's origin is its top left.
            let x = (CGFloat(point.x) + 1) / 2 * size.width
            let y = (1 - CGFloat(point.y)) / 2 * size.height
            Circle()
                .fill(color)
                .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                .offset(x: x - Self.dotDiameter / 2, y: y - Self.dotDiameter / 2)
        }
    }
}
