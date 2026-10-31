import SwiftUI

#if os(iOS)
struct FloatingSystemSelectorItem: Identifiable {
    let id: String
    let title: String
    let icon: Image
}

/// Compact system shortcuts that return automatically after paging settles.
struct FloatingSystemSelector: View {
    let items: [FloatingSystemSelectorItem]
    @Binding var selection: String
    let isPaging: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var isSettling = false
    @State private var lastTappedSelection: String?
    @State private var settleTask: Task<Void, Never>?

    private var isHidden: Bool { !voiceOver && (isPaging || isSettling) }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            icons.fixedSize(horizontal: true, vertical: false)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) { icons }
                    .onAppear { proxy.scrollTo(selection, anchor: .center) }
                    .onChange(of: selection) { _, value in
                        if reduceMotion { proxy.scrollTo(value, anchor: .center) }
                        else { withAnimation { proxy.scrollTo(value, anchor: .center) } }
                    }
            }
        }
        .frame(maxHeight: 52)
        .background(.regularMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(.primary.opacity(0.15), lineWidth: 1) }
        .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .opacity(isHidden ? 0 : 1)
        .allowsHitTesting(!isHidden)
        .accessibilityHidden(isHidden)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isHidden)
        .onChange(of: selection) { _, value in
            settleTask?.cancel()
            guard value != lastTappedSelection else {
                lastTappedSelection = nil
                isSettling = false
                return
            }
            isSettling = true
            settleTask = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(700)) }
                catch { return }
                isSettling = false
            }
        }
        .onDisappear {
            settleTask?.cancel()
            isSettling = false
            lastTappedSelection = nil
        }
    }

    private var icons: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                Button {
                    settleTask?.cancel()
                    isSettling = false
                    lastTappedSelection = item.id == selection ? nil : item.id
                    selection = item.id
                } label: {
                    item.icon.resizable().scaledToFit()
                        .frame(width: 28, height: 28)
                        .frame(width: 44, height: 44)
                        .background(selection == item.id ? Color.accentColor.opacity(0.2) : .clear, in: Circle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selection == item.id ? .isSelected : [])
                .help(item.title)
                .id(item.id)
            }
        }
        .padding(4)
    }
}
#endif
