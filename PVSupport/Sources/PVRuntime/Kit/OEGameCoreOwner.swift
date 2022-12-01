// Copyright (c) 2022, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import QuartzCore

public typealias OEContextID = UInt32

@objc(OEGameCoreOwner) public protocol OEGameCoreOwner: NSObjectProtocol {
    // MARK: - Actions
    
    func saveState()
    func loadState()
    func quickSave()
    func quickLoad()
    func toggleFullScreen()
    func toggleAudioMute()
    func volumeDown()
    func volumeUp()
    func stopEmulation()
    func resetEmulation()
    func toggleEmulationPaused()
    func takeScreenshot()
    func fastForwardGameplay(_ enable: Bool)
    func rewindGameplay(_ enable: Bool)
    func stepGameplayFrameForward()
    func stepGameplayFrameBackward()
    func nextDisplayMode()
    func lastDisplayMode()
    
    /// Notify the host application that the screen and aspect sizes have changed for the core.
    ///
    /// The host application would use this information to adjust the size of the display window.
    ///
    /// - Parameters:
    ///   - newScreenSize: The updated screen size
    ///   - newAspectSize: The updated aspect size
    func setScreenSize(_ newScreenSize: OEIntSize, aspectSize newAspectSize: OEIntSize)
    
    /// Notify the host application that the disc count has changed
    /// - Parameter discCount: The new disc count
    func setDiscCount(_ discCount: UInt)
    func setDisplayModes(_ displayModes: [[String: Any]])
    func setVideoLayer(_ layer: CALayer)
    
    /// Invoked when the game core execution has terminated.
    ///
    /// This may occur either because it was asked to stop, or because it
    /// terminated spontaneously (for example in case of a helper application crash).
    ///
    /// - Warning: This message may not be sent in certain situations (for example
    /// when the core manager is deallocated right after the game core is
    /// stopped).
    @objc optional func gameCoreDidTerminate()
}
