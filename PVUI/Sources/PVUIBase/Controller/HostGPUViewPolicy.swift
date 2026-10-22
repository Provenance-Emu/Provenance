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
    static func drawsGame(skipLayout: Bool, positionsOwnRenderView: Bool) -> Bool {
        !(skipLayout && positionsOwnRenderView)
    }
}
