//
//  TVFrameFailure.swift
//  PVUI
//
//  What to do when the GPU rejects a frame drawn through a TV.
//

import Foundation
import Metal

/// Sorts a failed command buffer's error into what the renderer can do about it.
///
/// A TV runs a multi-pass shader over the whole scene, the heaviest thing the app draws. A
/// GPU that cannot finish it in time hangs; after two GPU restarts iOS refuses every frame
/// the app submits until it is relaunched, and a new command queue is refused too.
enum TVFrameFailure {

    enum Action: Equatable {
        /// The frame took too long or faulted: stop drawing the TV and show the picture alone.
        case dropTV
        /// iOS has cut the app off from the GPU. Nothing can be drawn until it is reopened.
        case accessRevoked
        case logOnly
    }

    static func action(for error: Error) -> Action {
        let error = error as NSError
        guard error.domain == MTLCommandBufferErrorDomain,
              let code = MTLCommandBufferError.Code(rawValue: UInt(error.code)) else { return .logOnly }
        switch code {
        case .accessRevoked: return .accessRevoked
        case .timeout, .pageFault: return .dropTV
        default: return .logOnly
        }
    }
}
