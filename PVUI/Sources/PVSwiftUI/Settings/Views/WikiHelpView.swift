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
        .focusSection()
        .onExitCommand { dismiss() }
        #endif
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
            Button("Retry") {
                Task { await viewModel.loadNavigationTree() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func navigationList(tree: WikiNavigationTree) -> some View {
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
        #if os(tvOS)
        .listStyle(.grouped)
        #endif
    }

    private func navItemRow(_ item: WikiNavItem) -> AnyView {
        if item.children.isEmpty {
            return AnyView(
                NavigationLink(destination: WikiPageView(path: item.path, title: item.title)) {
                    Label(item.title, systemImage: iconForPath(item.path))
                }
            )
        } else {
            #if os(tvOS)
            // tvOS: navigate to an intermediate list for items with children
            return AnyView(
                NavigationLink(destination: wikiSubList(item: item)) {
                    Label(item.title, systemImage: iconForPath(item.path))
                }
            )
            #else
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
            #endif
        }
    }

    #if os(tvOS)
    private func wikiSubList(item: WikiNavItem) -> AnyView {
        AnyView(
            List {
                // Parent page link
                NavigationLink(destination: WikiPageView(path: item.path, title: item.title)) {
                    Label(item.title, systemImage: "doc.text")
                }
                // Children
                ForEach(item.children) { child in
                    if child.children.isEmpty {
                        NavigationLink(destination: WikiPageView(path: child.path, title: child.title)) {
                            Label(child.title, systemImage: iconForPath(child.path))
                        }
                    } else {
                        NavigationLink(destination: wikiSubList(item: child)) {
                            Label(child.title, systemImage: iconForPath(child.path))
                        }
                    }
                }
            }
            .navigationTitle(item.title)
            .listStyle(.grouped)
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
