import SwiftUI
import PVControllerDSU
import Network

/// Interactive virtual controller view backed by a live DSU server.
///
/// Renders a standard gamepad layout and forwards touch events to a
/// ``DSUSkinServer`` that broadcasts DSU packets over the local network.
/// Any DSU-compatible emulator (Cemu, Yuzu, Dolphin, Ryujinx, etc.) on
/// the same subnet receives the input as a connected controller.
///
/// For full Delta-skin rendering backed by the app group skin library,
/// a future iteration can swap `BuiltinGamepadLayout` for a loaded
/// `DeltaSkin` once `PVControllerDSU` is linked from the companion app.
@MainActor
struct VirtualControllerView: View {

    // MARK: - State

    @State private var server = DSUSkinServer()
    @State private var isServerRunning = false
    @State private var serverError: String?
    @State private var activeButtons: Set<String> = []

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            statusBanner
            Divider()
            controllerLayout
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Virtual Controller")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                toggleButton
            }
        }
        .alert("Server Error", isPresented: Binding(get: { serverError != nil }, set: { if !$0 { serverError = nil } })) {
            Button("OK", role: .cancel) { serverError = nil }
        } message: {
            if let msg = serverError { Text(msg) }
        }
        .task { await startServer() }
        .onDisappear { Task { await server.stop() } }
    }

    // MARK: - Subviews

    private var statusBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isServerRunning ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            Text(isServerRunning ? "Broadcasting on port \(DSUConstants.defaultPort)" : "Starting server…")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "wifi")
                .foregroundStyle(isServerRunning ? .green : .orange)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }

    private var toggleButton: some View {
        Button {
            Task {
                if isServerRunning { await stopServer() } else { await startServer() }
            }
        } label: {
            Label(isServerRunning ? "Stop" : "Start", systemImage: isServerRunning ? "stop.circle" : "play.circle")
        }
    }

    // MARK: - Gamepad layout

    private var controllerLayout: some View {
        GeometryReader { geo in
            let small = min(geo.size.width, geo.size.height)
            VStack(spacing: small * 0.05) {
                HStack {
                    dpad(size: small * 0.35)
                    Spacer()
                    faceButtons(size: small * 0.35)
                }
                HStack(spacing: small * 0.06) {
                    shoulderButton("l2", label: "L2", size: small * 0.15)
                    shoulderButton("l1", label: "L1", size: small * 0.15)
                    Spacer()
                    metaButton("select", label: "−", size: small * 0.12)
                    metaButton("start", label: "+", size: small * 0.12)
                    Spacer()
                    shoulderButton("r1", label: "R1", size: small * 0.15)
                    shoulderButton("r2", label: "R2", size: small * 0.15)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func dpad(size: CGFloat) -> some View {
        ZStack {
            // Vertical bar
            VStack(spacing: 0) {
                dpadButton("up",    icon: "chevron.up",    size: size / 3)
                Rectangle().fill(.clear).frame(width: size / 3, height: size / 3)
                dpadButton("down",  icon: "chevron.down",  size: size / 3)
            }
            // Horizontal bar
            HStack(spacing: 0) {
                dpadButton("left",  icon: "chevron.left",  size: size / 3)
                Rectangle().fill(.clear).frame(width: size / 3, height: size / 3)
                dpadButton("right", icon: "chevron.right", size: size / 3)
            }
        }
        .frame(width: size, height: size)
    }

    private func dpadButton(_ id: String, icon: String, size: CGFloat) -> some View {
        buttonShape(id: id, size: size) {
            Image(systemName: icon)
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundStyle(activeButtons.contains(id) ? .white : .primary)
        }
    }

    private func faceButtons(size: CGFloat) -> some View {
        let btnSize = size / 2.5
        return ZStack {
            buttonShape(id: "y", size: btnSize, label: "Y").offset(y: -btnSize)
            buttonShape(id: "x", size: btnSize, label: "X").offset(x: -btnSize)
            buttonShape(id: "b", size: btnSize, label: "B").offset(x:  btnSize)
            buttonShape(id: "a", size: btnSize, label: "A").offset(y:  btnSize)
        }
        .frame(width: size, height: size)
    }

    private func buttonShape(id: String, size: CGFloat, label: String) -> some View {
        buttonShape(id: id, size: size) {
            Text(label)
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundStyle(activeButtons.contains(id) ? .white : .primary)
        }
    }

    private func buttonShape<Content: View>(id: String, size: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(activeButtons.contains(id) ? Color.accentColor : Color(uiColor: .systemFill))
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in press(id) }
                    .onEnded   { _ in release(id) }
            )
    }

    private func shoulderButton(_ id: String, label: String, size: CGFloat) -> some View {
        Text(label)
            .font(.system(size: size * 0.3, weight: .semibold))
            .frame(width: size * 1.6, height: size)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(activeButtons.contains(id) ? Color.accentColor : Color(uiColor: .systemFill))
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in press(id) }
                    .onEnded   { _ in release(id) }
            )
    }

    private func metaButton(_ id: String, label: String, size: CGFloat) -> some View {
        Text(label)
            .font(.system(size: size * 0.45, weight: .medium))
            .frame(width: size * 1.4, height: size * 0.7)
            .background(
                Capsule()
                    .fill(activeButtons.contains(id) ? Color.accentColor : Color(uiColor: .systemFill))
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in press(id) }
                    .onEnded   { _ in release(id) }
            )
    }

    // MARK: - Server control

    private func startServer() async {
        do {
            try await server.start()
            isServerRunning = await server.isRunning
        } catch {
            serverError = error.localizedDescription
        }
    }

    private func stopServer() async {
        await server.stop()
        isServerRunning = false
    }

    // MARK: - Input forwarding

    private func press(_ id: String) {
        guard !activeButtons.contains(id) else { return }
        activeButtons.insert(id)
        Task { await server.updateButtonState(inputID: id, pressed: true) }
    }

    private func release(_ id: String) {
        activeButtons.remove(id)
        Task { await server.updateButtonState(inputID: id, pressed: false) }
    }
}

#Preview {
    NavigationStack {
        VirtualControllerView()
    }
}
