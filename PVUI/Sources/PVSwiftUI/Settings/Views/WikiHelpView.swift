import SwiftUI
import PVHelp
import PVUIBase
import PVThemes
import MarkdownView

public struct WikiHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WikiHelpViewModel()

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoadingTree {
                loadingView
            } else if let tree = viewModel.navigationTree {
                navigationList(tree: tree)
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                loadingView
            }
        }
        .navigationTitle("Help & Wiki")
        #if os(tvOS)
        .background { RetroSettingsBackground() }
        .focusSection()
        .onExitCommand { dismiss() }
        #endif
        .settingsSubpageTracking()
        .task {
            await viewModel.loadNavigationTree()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading wiki...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            retryButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var retryButton: some View {
        #if os(tvOS)
        RetroSettingsActionButton(title: "Retry", icon: "arrow.clockwise") {
            Task { await viewModel.loadNavigationTree() }
        }
        .frame(maxWidth: 480)
        #else
        Button("Retry") {
            Task { await viewModel.loadNavigationTree() }
        }
        #endif
    }

    @ViewBuilder
    private func navigationList(tree: WikiNavigationTree) -> some View {
        #if os(tvOS)
        ScrollView {
            tvOSRows {
                ForEach(tree.sections) { section in
                    if !section.title.isEmpty {
                        RetroSettingsSectionHeader(icon: "book", title: section.title)
                            .padding(.top, 12)
                    }
                    ForEach(section.items) { item in
                        tvOSNavItemRow(item)
                    }
                }
            }
        }
        #else
        List {
            ForEach(tree.sections) { section in
                if section.title.isEmpty {
                    // Root items (Welcome, FAQ) — no section header
                    ForEach(section.items) { item in
                        navItemRow(item)
                    }
                } else {
                    Section(header: Text(section.title)) {
                        ForEach(section.items) { item in
                            navItemRow(item)
                        }
                    }
                }
            }
        }
        #endif
    }

    #if !os(tvOS)
    private func navItemRow(_ item: WikiNavItem) -> AnyView {
        if item.children.isEmpty {
            return AnyView(
                NavigationLink(destination: WikiPageView(path: item.path, title: item.title)) {
                    Label(item.title, systemImage: iconForPath(item.path))
                }
            )
        } else {
            return AnyView(
                DisclosureGroup {
                    ForEach(item.children) { child in
                        navItemRow(child)
                    }
                } label: {
                    NavigationLink(destination: WikiPageView(path: item.path, title: item.title)) {
                        Label(item.title, systemImage: iconForPath(item.path))
                    }
                }
            )
        }
    }
    #endif

    #if os(tvOS)
    /// Retrowave row stack shared by the root list and the intermediate sub-lists.
    private func tvOSRows<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .tvOSSettingsHorizontalPadding()
        .padding(.vertical, 24)
    }

    private func tvOSRow<Destination: View>(title: String, icon: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            SettingsRow(title: title, icon: .sfSymbol(icon))
        }
        .retroFocusButtonStyle(showBorder: false)
    }

    /// Items with children open an intermediate list; leaf items open the page.
    @ViewBuilder
    private func tvOSNavItemRow(_ item: WikiNavItem) -> some View {
        if item.children.isEmpty {
            tvOSRow(title: item.title, icon: iconForPath(item.path),
                    destination: WikiPageView(path: item.path, title: item.title))
        } else {
            tvOSRow(title: item.title, icon: iconForPath(item.path),
                    destination: wikiSubList(item: item))
        }
    }

    private func wikiSubList(item: WikiNavItem) -> AnyView {
        AnyView(
            ZStack {
                RetroSettingsBackground()
                ScrollView {
                    tvOSRows {
                        // Parent page link
                        tvOSRow(title: item.title, icon: "doc.text",
                                destination: WikiPageView(path: item.path, title: item.title))
                        // Children
                        ForEach(item.children) { child in
                            tvOSNavItemRow(child)
                        }
                    }
                }
            }
            .focusSection()
            .navigationTitle(item.title)
        )
    }
    #endif

    private func iconForPath(_ path: String) -> String {
        if path.contains("controller") { return "gamecontroller" }
        if path.contains("cheat") { return "wand.and.stars" }
        if path.contains("bios") { return "cpu" }
        if path.contains("rom") || path.contains("importing") { return "square.and.arrow.down" }
        if path.contains("save") { return "externaldrive" }
        if path.contains("troubleshoot") { return "wrench.and.screwdriver" }
        if path.contains("faq") { return "questionmark.circle" }
        if path.contains("install") { return "arrow.down.app" }
        if path.contains("shader") || path.contains("filter") { return "camera.filters" }
        if path.contains("performance") { return "gauge.with.dots.needle.67percent" }
        if path.contains("tvos") || path.contains("apple-tv") { return "appletv" }
        if path.contains("ipad") { return "ipad" }
        if path.contains("skin") { return "paintbrush" }
        if path.contains("multiplayer") || path.contains("netplay") { return "person.2" }
        if path.contains("achievement") || path.contains("cheevo") { return "trophy" }
        if path.contains("contribute") { return "heart" }
        if path == "README.md" { return "house" }
        return "doc.text"
    }
}
