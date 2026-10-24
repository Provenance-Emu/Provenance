//
//  HostGPUViewPolicy.swift
//  PVUIBase
//
//  Whether the emulator view controller's own GPU view may be shown.
//

enum HostGPUViewPolicy {
    /// False for own-surface cores (Dolphin, Azahar): they skip the host layout and place a render
    /// view of their own next to the GPU view. The GPU view is opaque black, so any skin restack that
    /// puts it above that render view blacks the game out unless it stays hidden.
    /// `rendersInsideHostView`: the core had no host view and put its render view inside the GPU
    /// view (native PPSSPP under a skin), so hiding the GPU view would hide the game.
    static func drawsGame(skipLayout: Bool, positionsOwnRenderView: Bool, rendersInsideHostView: Bool) -> Bool {
        !(skipLayout && positionsOwnRenderView) || rendersInsideHostView
    }
}
