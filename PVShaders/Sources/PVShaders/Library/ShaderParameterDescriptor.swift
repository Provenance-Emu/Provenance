//
//  ShaderParameterDescriptor.swift
//  PVShaders
//

import Foundation

/// One adjustable value of a filter.
public struct ShaderParameterDescriptor: Codable, Hashable, Sendable, Identifiable {
    /// The parameter's name in the shader (`#pragma parameter` name, or the native key).
    public let name: String
    public let label: String
    public let initial: Float
    public let minimum: Float
    public let maximum: Float
    public let step: Float
    /// On/off switch rather than a slider (native filters' feature toggles).
    public let isToggle: Bool

    public var id: String { name }

    public init(name: String, label: String, initial: Float, minimum: Float, maximum: Float,
                step: Float, isToggle: Bool = false) {
        self.name = name
        self.label = label
        self.initial = initial
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
        self.isToggle = isToggle
    }

    enum CodingKeys: String, CodingKey {
        case name, label, initial, minimum, maximum, step, isToggle
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? name
        initial = try container.decode(Float.self, forKey: .initial)
        minimum = try container.decode(Float.self, forKey: .minimum)
        maximum = try container.decode(Float.self, forKey: .maximum)
        step = try container.decodeIfPresent(Float.self, forKey: .step) ?? 0
        isToggle = try container.decodeIfPresent(Bool.self, forKey: .isToggle) ?? false
    }

    /// Slang presets use a parameter whose range is empty as a section heading
    /// (`#pragma parameter CRT_HEADER "[ CRT SETTINGS ]" 0 0 0 0`).
    public var isHeading: Bool { !isToggle && minimum == maximum }

    /// `value` clamped to the range and snapped to `step`.
    public func clamp(_ value: Float) -> Float {
        guard minimum < maximum else { return minimum }
        var result = min(max(value, minimum), maximum)
        if step > 0 {
            result = minimum + ((result - minimum) / step).rounded() * step
            result = min(max(result, minimum), maximum)
        }
        return result
    }
}

/// Parameters of one filter split into titled sections for the editor.
public struct ShaderParameterGroup: Hashable, Sendable, Identifiable {
    /// `nil` for parameters that come before any heading.
    public let title: String?
    public let parameters: [ShaderParameterDescriptor]

    public var id: String { title ?? "" }

    public init(title: String?, parameters: [ShaderParameterDescriptor]) {
        self.title = title
        self.parameters = parameters
    }

    /// Splits at heading parameters. Headings whose section ends up empty are dropped.
    public static func groups(for parameters: [ShaderParameterDescriptor]) -> [ShaderParameterGroup] {
        var groups: [ShaderParameterGroup] = []
        var title: String?
        var current: [ShaderParameterDescriptor] = []
        func flush() {
            if !current.isEmpty {
                groups.append(ShaderParameterGroup(title: title, parameters: current))
            }
            current = []
        }
        for parameter in parameters {
            if parameter.isHeading {
                flush()
                title = cleanHeading(parameter.label)
            } else {
                current.append(parameter)
            }
        }
        flush()
        return groups
    }

    /// "[ CRT SETTINGS ]", "--- Mask ---", "### Glow" -> "CRT SETTINGS", "Mask", "Glow".
    static func cleanHeading(_ label: String) -> String? {
        let trimmed = label.trimmingCharacters(in: CharacterSet(charactersIn: " []-=#*:|~_"))
        return trimmed.isEmpty ? nil : trimmed
    }
}
