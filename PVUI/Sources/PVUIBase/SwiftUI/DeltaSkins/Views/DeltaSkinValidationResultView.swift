import SwiftUI

/// Displays skin validation results with severity icons and actionable fix suggestions
public struct DeltaSkinValidationResultView: View {
    public let result: DeltaSkinValidationResult

    public init(result: DeltaSkinValidationResult) {
        self.result = result
    }

    public var body: some View {
        List(result.findings) { finding in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName(for: finding.severity))
                    .foregroundColor(color(for: finding.severity))
                    .font(.title3)
                    .accessibilityLabel(accessibilityLabel(for: finding.severity))
                VStack(alignment: .leading, spacing: 4) {
                    Text(finding.title)
                        .fontWeight(.semibold)
                    Text(finding.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let suggestion = finding.suggestion {
                        Text(suggestion)
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle(result.isValid ? "Skin Valid" : "Validation Issues")
    }

    private func accessibilityLabel(for severity: DeltaSkinValidationSeverity) -> String {
        switch severity {
        case .info:    return "Info"
        case .warning: return "Warning"
        case .error:   return "Error"
        }
    }

    private func iconName(for severity: DeltaSkinValidationSeverity) -> String {
        switch severity {
        case .info:    return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error:   return "xmark.circle.fill"
        }
    }

    private func color(for severity: DeltaSkinValidationSeverity) -> Color {
        switch severity {
        case .info:    return .green
        case .warning: return .orange
        case .error:   return .red
        }
    }
}
