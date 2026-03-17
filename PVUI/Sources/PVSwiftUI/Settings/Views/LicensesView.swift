//
//  LicensesView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//  Rewritten as pure SwiftUI by Agent (issue #3235)
//

import SwiftUI
import PVLibrary
import PVThemes
import RealmSwift
import PVUIBase
#if canImport(SafariServices)
import SafariServices
#endif

// MARK: - License Group

/// License grouping by SPDX family.
/// When PVCore gains a `license` field (#3236), these can be derived from it.
/// For now every core is placed in the "Other / TBD" bucket.
private enum LicenseGroup: String, CaseIterable, Identifiable {
    case gpl   = "GPL"
    case lgpl  = "LGPL"
    case mit   = "MIT"
    case bsd   = "BSD"
    case other = "Other / TBD"

    var id: String { rawValue }

    /// Gradient colours used for the badge
    var badgeColors: [Color] {
        switch self {
        case .gpl:   return [.retroPink, .retroPurple]
        case .lgpl:  return [.retroPurple, .retroBlue]
        case .mit:   return [Color(red: 0.2, green: 0.8, blue: 0.6), .retroBlue]
        case .bsd:   return [Color(red: 0.9, green: 0.6, blue: 0.1), Color(red: 0.8, green: 0.3, blue: 0.1)]
        case .other: return [Color.gray.opacity(0.8), Color.gray.opacity(0.5)]
        }
    }

    /// Classify a raw SPDX string.
    /// Returns `.other` when the string is empty or unrecognised.
    static func classify(_ spdx: String) -> LicenseGroup {
        let upper = spdx.uppercased()
        if upper.contains("LGPL") { return .lgpl }
        if upper.contains("GPL")  { return .gpl }
        if upper.contains("MIT")  { return .mit }
        if upper.contains("BSD")  { return .bsd }
        return .other
    }
}

// MARK: - Sort Order

private enum SortOrder: String, CaseIterable, Identifiable {
    case name    = "Name"
    case license = "License"

    var id: String { rawValue }
}

// MARK: - LicensesView

struct LicensesView: View {

    // MARK: State

    @State private var searchText  = ""
    @State private var sortOrder   = SortOrder.name
    @State private var selectedURL: URL?
    @State private var showingSafari = false
    @ObservedObject private var themeManager = ThemeManager.shared

    // MARK: Data

    /// All cores loaded once at init and stored as plain Swift values so the
    /// view doesn't need to touch Realm on every redraw.
    private let cores: [PVCore]

    init() {
        self.cores = RomDatabase.sharedInstance
            .all(PVCore.self, sortedByKeyPath: #keyPath(PVCore.projectName))
            .toArray()
    }

    // MARK: Derived

    private var filtered: [PVCore] {
        guard !searchText.isEmpty else { return cores }
        return cores.filter {
            $0.projectName.localizedCaseInsensitiveContains(searchText) ||
            $0.projectURL.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sorted: [PVCore] {
        switch sortOrder {
        case .name:
            return filtered.sorted { $0.projectName.localizedCompare($1.projectName) == .orderedAscending }
        case .license:
            // Once #3236 lands and PVCore has a `license` property, sort by it.
            // Until then all entries share "TBD", so fall back to name order.
            return filtered.sorted { $0.projectName.localizedCompare($1.projectName) == .orderedAscending }
        }
    }

    /// Grouped and sorted for section display.
    private var groupedCores: [(group: LicenseGroup, cores: [PVCore])] {
        var buckets: [LicenseGroup: [PVCore]] = [:]
        for core in sorted {
            // TODO(#3236): replace empty string with core.license when available
            let group = LicenseGroup.classify("")
            buckets[group, default: []].append(core)
        }
        return LicenseGroup.allCases.compactMap { group in
            guard let members = buckets[group], !members.isEmpty else { return nil }
            return (group: group, cores: members)
        }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RetroGridForSettings()
                .ignoresSafeArea()
                .opacity(0.3)

            VStack(spacing: 0) {
                headerView
                controlsBar
                coreList
            }
        }
        .navigationTitle("Licenses")
        .tvOSNavigationSupport(title: "Licenses")
#if !os(tvOS)
        .sheet(isPresented: $showingSafari) {
            if let url = selectedURL {
                SafariSheetView(url: url)
            }
        }
#endif
    }

    // MARK: Sub-views

    private var headerView: some View {
        Text("LICENSES")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    private var controlsBar: some View {
        VStack(spacing: 8) {
#if !os(tvOS)
            // Search bar — SearchField not available on tvOS
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.retroBlue)
                TextField("Search licenses…", text: $searchText)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
#if !os(tvOS)
                    .textInputAutocapitalization(.never)
#endif
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.retroBlue.opacity(0.5), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
#endif

            // Sort picker
            HStack {
                Text("Sort:")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 14))
                Picker("Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private var coreList: some View {
        List {
            ForEach(groupedCores, id: \.group.id) { section in
                Section {
                    ForEach(section.cores, id: \.identifier) { core in
                        LicenseRowView(
                            core: core,
                            group: section.group,
                            onOpenURL: openURL(_:)
                        )
                    }
                } header: {
                    groupHeader(for: section.group)
                }
            }
        }
        .listStyle(.plain)
        .background(Color.clear)
        .scrollContentBackground(.hidden)
    }

    private func groupHeader(for group: LicenseGroup) -> some View {
        Text(group.rawValue)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(colors: group.badgeColors),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.vertical, 4)
    }

    // MARK: Helpers

    private func openURL(_ url: URL) {
#if os(tvOS)
        // tvOS: open in the system browser
        UIApplication.shared.open(url)
#else
        selectedURL = url
        showingSafari = true
#endif
    }
}

// MARK: - LicenseRowView

private struct LicenseRowView: View {
    let core: PVCore
    let group: LicenseGroup
    let onOpenURL: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(core.projectName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    if !core.projectVersion.isEmpty {
                        Text("v\(core.projectVersion)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.retroBlue)
                    }
                }

                Spacer()

                licenseBadge
            }

            // Project URL
            if !core.projectURL.isEmpty, let url = URL(string: core.projectURL) {
                projectLinkButton(url: url)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    group.badgeColors[0].opacity(0.5),
                                    group.badgeColors.last!.opacity(0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: group.badgeColors[0].opacity(0.15), radius: 6, x: 0, y: 3)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    private var licenseBadge: some View {
        // TODO(#3236): replace "TBD" with core.license when available
        let label = "TBD"
        return Text(label)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: group.badgeColors),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(colors: group.badgeColors),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }

    private func projectLinkButton(url: URL) -> some View {
        Button {
            onOpenURL(url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Project Website")
                    .foregroundColor(.white)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SafariSheetView

#if !os(tvOS)
/// Thin wrapper around `SFSafariViewController` for use as a SwiftUI sheet.
private struct SafariSheetView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
#endif
