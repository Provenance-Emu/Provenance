import SwiftUI

// MARK: - Main View

public struct RoadmapView: View {
    @State private var epics: [RoadmapEpic] = RoadmapLoader.loadAll()
    @State private var filter: EpicStatus? = nil

    private var displayed: [RoadmapEpic] {
        let base = filter == nil ? epics : epics.filter { $0.status == filter }
        return base.sorted { lhs, rhs in
            if lhs.status == .complete && rhs.status != .complete { return false }
            if lhs.status != .complete && rhs.status == .complete { return true }
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.progress > rhs.progress
        }
    }

    public init() {}

    public var body: some View {
        List {
            filterPicker
            ForEach(displayed) { epic in
                EpicRowView(epic: epic)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Roadmap")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: filter == nil) { filter = nil }
                FilterChip(title: "Active", isSelected: filter == .active, color: .blue) { filter = .active }
                FilterChip(title: "Planned", isSelected: filter == .planned, color: .gray) { filter = .planned }
                FilterChip(title: "Complete", isSelected: filter == .complete, color: .green) { filter = .complete }
                FilterChip(title: "On Hold", isSelected: filter == .onHold, color: .orange) { filter = .onHold }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

// MARK: - Epic Row

struct EpicRowView: View {
    let epic: RoadmapEpic
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(epic.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if epic.provenancePlus {
                            Text("PLUS")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(
                                        colors: [.retroPink, .retroPurple],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 6) {
                        StatusBadge(status: epic.status)
                        PriorityBadge(priority: epic.priority)
                        EffortBadge(effort: epic.effort)
                    }
                }

                Spacer()

                if let url = epic.githubURL {
                    Button {
                        openURL(url)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(epic.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if epic.progress > 0 && epic.status != .planned {
                ProgressView(value: epic.progress)
                    .tint(epic.status == .complete ? .green : .retroBlue)
                    .overlay(alignment: .trailing) {
                        Text("\(Int(epic.progress * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .offset(x: 36)
                    }
                    .padding(.trailing, 40)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(epic.status.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Badges

private struct StatusBadge: View {
    let status: EpicStatus
    var body: some View {
        Label(status.displayName, systemImage: status.systemImage)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(status.color.opacity(0.15))
            .clipShape(Capsule())
    }
}

private struct PriorityBadge: View {
    let priority: EpicPriority
    var body: some View {
        Text(priority.rawValue)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(priority.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(priority.color.opacity(0.15))
            .clipShape(Capsule())
    }
}

private struct EffortBadge: View {
    let effort: EpicEffort
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "clock")
                .font(.system(size: 9))
            Text(effort.rawValue)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.secondary.opacity(0.1))
        .clipShape(Capsule())
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = .retroBlue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Summary (for Settings About tab)

public struct RoadmapSummarySection: View {
    private let epics = RoadmapLoader.loadAll()

    private var activeCount: Int { epics.filter { $0.status == .active }.count }
    private var completedCount: Int { epics.filter { $0.status == .complete }.count }
    private var overallProgress: Double {
        guard !epics.isEmpty else { return 0 }
        return epics.map(\.progress).reduce(0, +) / Double(epics.count)
    }

    public init() {}

    public var body: some View {
        HStack(spacing: 16) {
            stat(value: "\(activeCount)", label: "In Progress", color: .blue)
            Divider().frame(height: 32)
            stat(value: "\(completedCount)", label: "Complete", color: .green)
            Divider().frame(height: 32)
            VStack(spacing: 4) {
                Text("\(Int(overallProgress * 100))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.retroBlue)
                Text("Overall")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func stat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
