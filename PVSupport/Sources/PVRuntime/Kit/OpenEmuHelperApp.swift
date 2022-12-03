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

import AudioToolbox
import QuartzCore
import Foundation
import OpenEmuShaders
import GameController
import Metal
@_implementationOnly import os.log

extension OSLog {
    static let display  = OSLog(subsystem: "org.openemu.OpenEmuKit", category: "display")
    static let renderer = OSLog(subsystem: "org.openemu.OpenEmuKit", category: "renderer")
}

@objc public class OpenEmuHelperApp: NSObject {
    public var gameCoreOwner: OEGameCoreOwner!
    public private(set) var gameCore: OEGameCore
    
    // MARK: - State
    // swiftlint:disable identifier_name
    var _previousScreenRect: OEIntRect = .init()
    var _previousAspectSize: OEIntSize = .init()
    
    // Video
    var _gameRenderer: GameRenderer!
    var _openGLGameRenderer: OpenGLGameRenderer?
    var _surface: CoreVideoTexture!
    var flipVertically: Bool = false
    
    // OE stuff
    var _gameController: OEGameCoreController!
    var _gameAudio: GameAudio!
    
    // initial shader and parameters
    var _shader: URL?
    var _shaderParameters: [String: Double]?
    
    var _currentShader: URL?
    
    var _videoLayer: GameHelperMetalLayer!
    var _filterChain: FilterChain!
    var _screenshot: Screenshot!
    /// Only send 1 frame at once to the GPU.
    /// Since we aren't synced to the display, even one more
    /// is enough to block in nextDrawable for more than a frame
    /// and cause audio skipping.
    var _inflightSemaphore = DispatchSemaphore(value: 1)
    var _scope: MTLCaptureScope!
    var _device: MTLDevice!
    var _commandQueue: MTLCommandQueue!
    var _clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    var _skippedFrames: UInt = 0
    var _effectsMode: OEGameCoreEffectsMode = .reflectPaused
    
    var _hasStartedAudio = false
    var _adaptiveSyncEnabled = false
    
    var loadedRom = false
    
    // frame rate debugging
    var previous    = CFTimeInterval()
    var frameRate   = CFTimeInterval()
    var lastLog     = CFTimeInterval()
    
    public init(_ core: OEGameCore) {
        self.gameCore = core
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: -
    
    private func setupGameCoreAudioAndVideo() {
        // 1. Audio
        _gameAudio = GameAudio(withCore: gameCore)
        _gameAudio.volume = 1.0
        
        // 2. Video
        _device         = MTLCreateSystemDefaultDevice()
        _scope          = MTLCaptureManager.shared().makeCaptureScope(device: _device)
        _commandQueue   = _device.makeCommandQueue()
        // TODO: Handle error
        // Original Obj-C didn't handle the error either
        _filterChain    = try? FilterChain(device: _device)
        _screenshot     = Screenshot(device: _device)
        
        updateScreenSize()
        setupGameRenderer()
        setupCVBuffer()
        setupRemoteLayer()
        if let _shader = _shader {
            try? setShaderURL(_shader, parameters: _shaderParameters)
            self._shader            = nil
            self._shaderParameters  = nil
        }
    }
    
    // MARK: - Core Video and Generic Video
    
    private func updateScreenSize() {
        _previousAspectSize = gameCore.aspectSize
        _previousScreenRect = gameCore.screenRect
    }
    
    private func setupGameRenderer() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        
        _videoLayer = .init()
        _videoLayer.device = _device
        _videoLayer.isOpaque = true
        _videoLayer.framebufferOnly = true
#if os(macOS)
        _videoLayer.displaySyncEnabled = true
#endif
        
        let rendering = gameCore.gameCoreRendering
        switch rendering {
        case .rendering2DVideo:
            _gameRenderer = setup2dVideo()
            
        case .renderingOpenGL2Video, .renderingOpenGL3Video:
            _openGLGameRenderer = setupOpenGLVideo()
            _gameRenderer       = _openGLGameRenderer
            
        default:
            fatalError("Rendering API \(rendering) not supported")
        }
    }
    
    private func setup2dVideo() -> GameRenderer {
        do {
            return try MTLGameRenderer(withDevice: _device, gameCore: gameCore)
        } catch {
            fatalError("Unable to create MTLGameRenderer")
        }
    }
    
    private func setupOpenGLVideo() -> OpenGLGameRenderer {
        precondition(gameCore.gameCoreRendering == .renderingOpenGL2Video || gameCore.gameCoreRendering == .renderingOpenGL3Video)
        _surface = CoreVideoTexture(device: _device, metalPixelFormat: .bgra8Unorm)
        
        switch gameCore.gameCoreRendering {
#if os(macOS)
        case .renderingOpenGL2Video:
            os_log(.debug, log: .display, "Using GL 2.x renderer")
            return OpenGL2GameRenderer(withInteropTexture: _surface, gameCore: gameCore)
        case .renderingOpenGL3Video:
            os_log(.debug, log: .display, "Using GL 3.x renderer")
            return OpenGL3GameRenderer(withInteropTexture: _surface, gameCore: gameCore)
#else
        case .renderingOpenGLES3Video:
            os_log(.debug, log: .display, "Using GLES 3 renderer")
            return OpenGLES3GameRenderer(withInteropTexture: _surface, gameCore: gameCore)
#endif
        default:
            fatalError("Expected OpenGL renderer")
        }
    }
    
    private func setupCVBuffer() {
        let surfaceSize = gameCore.bufferSize
        let size = CGSize(width: CGFloat(surfaceSize.width), height: CGFloat(surfaceSize.height))
        
        if gameCore.gameCoreRendering != .rendering2DVideo {
            _surface.size = size
            flipVertically = _surface.metalTextureIsFlippedVertically
            os_log(.debug, log: .display, "Updated GL render surface size to %{public}@", NSStringFromOEIntSize(surfaceSize))
        } else {
            os_log(.debug, log: .display, "Set 2D buffer size to %{public}@", NSStringFromOEIntSize(surfaceSize))
        }
        
        _gameRenderer.update()
        let rect = gameCore.screenRect
        let sourceRect = CGRect(x: CGFloat(rect.origin.x), y: CGFloat(rect.origin.y),
                                width: CGFloat(rect.size.width), height: CGFloat(rect.size.height))
        let aspectSize = CGSize(width: CGFloat(gameCore.aspectSize.width),
                                height: CGFloat(gameCore.aspectSize.height))

        #if os(macOS)
        os_log(.debug, log: .display,
               "Set FilterChain sourceRect to %{public}@, aspectSize to %{public}@",
               NSStringFromRect(sourceRect),
               NSStringFromSize(aspectSize))
        #else
        os_log(.debug, log: .display,
               "Set FilterChain sourceRect to %{public}@, aspectSize to %{public}@",
               NSCoder.string(for: sourceRect),
               NSCoder.string(for: aspectSize))
        #endif
        _filterChain.setSourceRect(sourceRect, aspect: aspectSize)
    }
    
    private func setupRemoteLayer() {
        CATransaction.begin()
        do {
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            
            // TODO: If there's a good default bounds, use that.
            _videoLayer.bounds = .init(x: 0, y: 0, width: Int(gameCore.bufferSize.width), height: Int(gameCore.bufferSize.height))
            _filterChain.drawableSize = _videoLayer.drawableSize
        }
        
        gameCoreOwner.setVideoLayer(_videoLayer)
    }
    
    // MARK: - Game Core methods
    
    public func load(withStartupInfo info: OEGameStartupInfo) throws {
        guard !loadedRom
        else {
            // throw
            return // NO
        }
        
        let aPath = info.romURL.standardizedFileURL.path
        
        os_log(.info, log: .helper, "Load ROM at path %{public}@", aPath)
        
        _shader = info.shaderURL
        _shaderParameters = info.shaderParameters

        gameCore.owner          = _gameController
        gameCore.delegate       = self
        gameCore.renderDelegate = self
        gameCore.audioDelegate  = self
        
        gameCore.systemIdentifier   = info.systemIdentifier
        gameCore.systemRegion       = info.systemRegion
        gameCore.displayModeInfo    = info.displayModeInfo ?? [:]
        gameCore.rommd5             = info.romMD5
        gameCore.romHeader          = info.romHeader
        gameCore.romSerial          = info.romSerial
        
        os_log(.debug, log: .helper, "Loaded bundle.")
        
        guard FileManager.default.isReadableFile(atPath: aPath)
        else {
            os_log(.error, log: .helper, "Unable to access file at path %{public}@", aPath)
            
            throw NSError(domain: OEGameCoreErrorDomain,
                          code: OEGameCoreErrorCodes.couldNotLoadROMError.rawValue,
                          userInfo: [
                            NSLocalizedDescriptionKey: NSLocalizedString("The emulator does not have read permissions to the ROM.",
                                                                         comment: "Error when loading a ROM."),
                          ])
        }
        
        do {
            try gameCore.loadFile(atPath: aPath)
            os_log(.debug, log: .helper, "Loaded new ROM: %{public}@", aPath)
            
            gameCoreOwner.setDiscCount(gameCore.discCount)
            if let displayModes = gameCore.displayModes {
                gameCoreOwner.setDisplayModes(displayModes)
            }
            
            loadedRom = true
        } catch {
            os_log(.debug, log: .helper, "Failed to load ROM.")
            
            throw NSError(domain: OEGameCoreErrorDomain,
                          code: OEGameCoreErrorCodes.couldNotLoadROMError.rawValue,
                          userInfo: [
                            NSLocalizedDescriptionKey: NSLocalizedString("The emulator could not load ROM.",
                                                                         comment: "Error when loading a ROM."),
                          ])
        }
    }
    
    // MARK: - OEGameCoreOwner subclass handles
    
    private func updateScreenSize(_ newScreenSize: OEIntSize, aspectSize newAspectSize: OEIntSize) {
        os_log(.debug, log: .display,
               "Notify OEGameCoreOwner of display size update: screenSize = %{public}@, aspectSize = %{public}@",
               NSStringFromOEIntSize(newScreenSize),
               NSStringFromOEIntSize(newAspectSize))
        
        gameCoreOwner.setScreenSize(newScreenSize, aspectSize: newAspectSize)
    }
    
    // MARK: - OEGameCoreHelper
    
    var _romName: String? = nil
    var _saveStatesPath: String? = nil
    var _batterySavesPath: String? = nil
    var _coreIdentifier: String? = nil
    var _screenType: String? = nil
    
    public weak var runStateDelegate: OEGameCoreHelperRunStateDelegate?
}

// MARK: - OEGameCoreHelper methods

extension OpenEmuHelperApp: OEGameCoreHelper {
    // TODO: renderFPS
    public var renderFPS: Double { 0 }
    public var frameInterval: Double { gameCore.frameInterval }
    
    public var controller1: GCController? { get { nil } set { } }
    public var controller2: GCController? { get { nil } set { } }
    public var controller3: GCController? { get { nil } set { } }
    public var controller4: GCController? { get { nil } set { } }
    
    public var romName: String? {
        get { _romName }
        set { _romName = newValue }
    }
    
    public var saveStatesPath: String? {
        get { _saveStatesPath }
        set { _saveStatesPath = newValue }
    }
    
    public var batterySavesPath: String? {
        get { _batterySavesPath }
        set { _batterySavesPath = newValue }
    }
    
    // TODO: Add to OEGameCore
    public var biosPath: String? {
        get { nil }
        set {  }
    }
    
    public var systemIdentifier: String? {
        get { gameCore.systemIdentifier }
        set { gameCore.systemIdentifier = newValue }
    }
    
    public var coreIdentifier: String? {
        get { _coreIdentifier }
        set { _coreIdentifier = newValue }
    }
    
    public var romMD5: String? {
        get { gameCore.rommd5 }
        set { gameCore.rommd5 = newValue }
    }
    
    public var romSerial: String? {
        get { gameCore.romSerial }
        set { gameCore.romSerial = newValue }
    }
    
    public var screenType: String? {
        get { _screenType }
        set { _screenType = newValue }
    }
    
    // TODO: Add to OEGameCore
    public var supportsSaveStates: Bool {
        false
    }
    
    public var responderClient: AnyObject? { gameCore }
    public var viewController: AnyObject? { nil }
    
    public var features: AnyObject? { nil }
    
    public func setVolume(_ volume: Float) {
        gameCore.perform {
            self._gameAudio.volume = volume
        }
    }
    
    public func setPauseEmulation(_ paused: Bool) {
        gameCore.perform {
            self.gameCore.setPauseEmulation(paused)
            if paused {
                self.runStateDelegate?.helper(self, didChangeState: .paused)
            } else {
                self.runStateDelegate?.helper(self, didChangeState: .running)
            }
        }
    }
    
    public func setEffectsMode(_ mode: OEGameCoreEffectsMode) {
        _effectsMode = mode
    }

#if os(macOS)
    public func setAudioOutputDeviceID(_ deviceID: AudioDeviceID) {
        os_log(.debug, log: .helper, "Set audio output to device number 0x%x", UInt32(deviceID))
        
        gameCore.perform {
            self._gameAudio.setOutputDeviceID(deviceID)
        }
    }
#endif
    
    public func setOutputBounds(_ rect: CGRect) {
#if os(macOS)
        os_log(.debug, log: .display, "Output bounds changed to %{public}@", NSStringFromRect(rect))
#else
        os_log(.debug, log: .display, "Output bounds changed to %{public}@", NSCoder.string(for: rect))
#endif
        
        if let _videoLayer = _videoLayer, _videoLayer.bounds != rect {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            
            _videoLayer.bounds = rect
            _filterChain.drawableSize = _videoLayer.drawableSize
        }
        
        // Game will try to render at the window size on its next frame.
        guard _gameRenderer.canChangeBufferSize else { return }
        
        let newBufferSize = OEIntSize(width: Int32(rect.size.width.rounded(.up)), height: Int32(rect.size.height.rounded(.up)))
        gameCore.tryToResizeVideo(to: newBufferSize)
    }
    
    public func setBackingScaleFactor(_ newBackingScaleFactor: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        
        _videoLayer.contentsScale = newBackingScaleFactor
        _filterChain.drawableSize = _videoLayer.drawableSize
    }
    
    public func setAdaptiveSyncEnabled(_ enabled: Bool) {
        os_log(.debug, log: .default, "Set adaptive sync enabled: %@", enabled ? "YES" : "NO")
        _adaptiveSyncEnabled = true
    }
    
    public func setShaderURL(_ url: URL, parameters: [String: NSNumber]?, completionHandler block: @escaping (Error?) -> Void) {
        gameCore.perform {
            do {
                try self.setShaderURL(url, parameters: parameters as? [String: Double])
                block(nil)
            } catch {
                block(error)
            }
        }
    }
    
    func setShaderURL(_ url: URL, parameters: [String: Double]?) throws {
        if _currentShader != url {
            try _filterChain.setShader(fromURL: url, options: .makeOptions())
            _currentShader = url
        }
        
        if let parameters = parameters, let filter = _filterChain {
            for (key, val) in parameters {
                filter.setValue(CGFloat(val), forParameterName: key)
            }
        }
    }
    
    public func setShaderParameterValue(_ value: CGFloat, forKey key: String) {
        _filterChain.setValue(value, forParameterName: key)
    }
    
    public func loadFile(atPath path: String) throws {
        
    }
    
    public func setupEmulation(completionHandler handler: @escaping (_ screenSize: OEIntSize, _ aspectSize: OEIntSize) -> Void) {
        gameCore.setupEmulation {
            self.setupGameCoreAudioAndVideo()
            
            handler(self._previousScreenRect.size, self._previousAspectSize)
        }
    }
    
    public func startEmulation(completionHandler handler: @escaping () -> Void) {
        gameCore.startEmulation(completionHandler: handler)
        self.runStateDelegate?.helper(self, didChangeState: .running)
    }
    
    public func resetEmulation(completionHandler handler: @escaping () -> Void) {
        gameCore.resetEmulation(completionHandler: handler)
    }
    
    public func stopEmulation(completionHandler handler: @escaping () -> Void) {
        gameCore.stopEmulation {
            self._gameAudio.stopAudio()
            self.gameCore.renderDelegate = nil
            self.gameCore.audioDelegate = nil
            self.gameCoreOwner = nil
            self._gameAudio = nil
            
            handler()
        }
        self.runStateDelegate?.helper(self, didChangeState: .stopped)
    }
    
    public func saveStateToFile(at fileURL: URL, completionHandler block: @escaping (Bool, Error?) -> Void) {
        gameCore.perform {
            self.gameCore.saveStateToFile(atPath: fileURL.path, completionHandler: block)
        }
    }
    
    public func loadStateFromFile(at fileURL: URL, completionHandler block: @escaping (Bool, Error?) -> Void) {
        gameCore.perform {
            self.gameCore.loadStateFromFile(atPath: fileURL.path, completionHandler: block)
        }
    }
    
    public func setCheat(_ cheatCode: String, withType type: String, enabled: Bool) {
        gameCore.perform {
            self.gameCore.setCheat(cheatCode, setType: type, setEnabled: enabled)
        }
    }
    
    public func setDisc(_ discNumber: UInt) {
        gameCore.perform {
            self.gameCore.setDisc(discNumber)
        }
    }
    
    public func changeDisplay(withMode displayMode: String) {
        gameCore.perform {
            self.gameCore.changeDisplay(withMode: displayMode)
            if let displayModes = self.gameCore.displayModes {
                self.gameCoreOwner.setDisplayModes(displayModes)
            }
        }
    }
    
    public func insertFile(at url: URL, completionHandler block: @escaping (Bool, Error?) -> Void) {
        gameCore.perform {
            self.gameCore.insertFile(at: url, completionHandler: block)
        }
    }
    
    // MARK: - OEGameCoreOwner image capture
    
    public func captureOutputImage(completionHandler block: @escaping (CGImage) -> Void) {
        let gr      = _gameRenderer!
        let ss      = _screenshot!
        let chain   = _filterChain!
        let flipped = flipVertically
        gameCore.perform {
            let cgImg = ss.getCGImageFromOutput(gameRenderer: gr, filterChain: chain, flippedVertically: flipped)
            block(cgImg)
        }
    }
    
    public func captureSourceImage(completionHandler block: @escaping (CGImage) -> Void) {
        let gr      = _gameRenderer!
        let ss      = _screenshot!
        let flipped = flipVertically
        gameCore.perform {
            let cgImg = ss.getCGImageFromGameRenderer(gr, flippedVertically: flipped)
            block(cgImg)
        }
    }
}

extension OpenEmuHelperApp: OERenderDelegate {
    public func presentDoubleBufferedFBO() {
        _openGLGameRenderer?.presentDoubleBufferedFBO()
    }
    
    public func willRenderFrameOnAlternateThread() {
        _openGLGameRenderer?.willRenderFrameOnAlternateThread()
    }
    
    public func didRenderFrameOnAlternateThread() {
        _openGLGameRenderer?.didRenderFrameOnAlternateThread()
    }
    
    public var presentationFramebuffer: Any? {
        _openGLGameRenderer?.presentationFramebuffer
    }
    
    public func willExecute() {
        _gameRenderer.willExecuteFrame()
    }
    
    public func didExecute() {
        let previousBufferSize = _gameRenderer.surfaceSize
        let previousAspectSize = _previousAspectSize
        let previousScreenRect = _previousScreenRect
        
        let bufferSize = gameCore.bufferSize
        let screenRect = gameCore.screenRect
        let aspectSize = gameCore.aspectSize
        var mustUpdate = false
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        if previousBufferSize != bufferSize {
            os_log(.debug, log: .display,
                   "Game core buffer size change: %{public}@ → %{public}@",
                   NSStringFromOEIntSize(previousBufferSize),
                   NSStringFromOEIntSize(bufferSize))
            precondition(_gameRenderer.canChangeBufferSize, "Game tried changing IOSurface in a state we don't support")
            
            setupCVBuffer()
        } else {
            if screenRect != previousScreenRect {
                precondition(screenRect.origin.x + screenRect.size.width <= bufferSize.width, "screen rect must not be larger than buffer size")
                precondition(screenRect.origin.y + screenRect.size.height <= bufferSize.height, "screen rect must not be larger than buffer size")
                
                os_log(.debug, log: .display,
                       "Game core screen rect change: %{public}@ → %{public}@",
                       NSStringFromOEIntRect(previousScreenRect),
                       NSStringFromOEIntRect(screenRect))
                mustUpdate = true
            }
            
            if aspectSize != previousAspectSize {
                os_log(.debug, log: .display,
                       "Game core aspect size change: %{public}@ → %{public}@",
                       NSStringFromOEIntSize(previousAspectSize),
                       NSStringFromOEIntSize(aspectSize))
                mustUpdate = true
            }
            
            if mustUpdate {
                updateScreenSize()
                updateScreenSize(_previousScreenRect.size, aspectSize: _previousAspectSize)
                setupCVBuffer()
            }
        }
        
        _gameRenderer.didExecuteFrame()
        
        CATransaction.commit()
        
        if !_hasStartedAudio {
            _gameAudio.startAudio()
            _hasStartedAudio = true
        }
    }
    
    public func suspendFPSLimiting() {
        _gameRenderer.suspendFPSLimiting()
    }
    
    public func resumeFPSLimiting() {
        _gameRenderer.resumeFPSLimiting()
    }
}

// MARK: - OEAudioDelegate

extension OpenEmuHelperApp: OEAudioDelegate {
    public func audioSampleRateDidChange() {
        gameCore.perform {
            self._gameAudio.audioSampleRateDidChange()
        }
    }
    
    public func pauseAudio() {
        gameCore.perform {
            self._gameAudio.pauseAudio()
        }
    }
    
    public func resumeAudio() {
        gameCore.perform {
            self._gameAudio.resumeAudio()
        }
    }
}

extension OpenEmuHelperApp: OEGameCoreDelegate {
    public func gameCoreDidFinishFrameRefreshThread(_ gameCore: OEGameCore) {
        os_log(.debug, log: .helper, "Finishing separate thread, stopping")
        CFRunLoopStop(CFRunLoopGetCurrent())
    }
    
    public func gameCoreWillBeginFrame() {
        _scope.begin()
    }
    
    public func gameCoreWillEndFrame() {
        defer {
            _scope.end()
            // _videoLayer.display()
        }
        
        guard !gameCore.isEmulationPaused || _effectsMode == .displayAlways
        else { return }
        
        guard _inflightSemaphore.wait(timeout: .now()) == .success
        else {
            _skippedFrames += 1
            return
        }
        
        autoreleasepool {
            // Ensure signal if we do not add it to finalCB
            var skipped: DispatchSemaphore? = _inflightSemaphore
            defer {
                if let skipped = skipped {
                    os_log(.debug, log: .display, "Skipping frame.")
                    _skippedFrames += 1
                    skipped.signal()
                }
            }
            
            guard let offscreenCB = _commandQueue.makeCommandBuffer() else { return }
            offscreenCB.label = "offscreen"
            offscreenCB.enqueue()
            if let sourceTexture = _gameRenderer.prepareFrameForRender(commandBuffer: offscreenCB) {
                _filterChain.renderOffscreenPasses(sourceTexture: sourceTexture, commandBuffer: offscreenCB)
            }
            offscreenCB.commit()
            
            guard let drawable = _videoLayer.nextDrawable() else { return }
            
            let rpd = MTLRenderPassDescriptor()
            rpd.colorAttachments[0].clearColor = _clearColor
            // TODO: Investigate whether we can avoid the MTLLoadActionClear
            // Frame buffer should be overwritten completely by final pass.
            rpd.colorAttachments[0].loadAction = .clear
            rpd.colorAttachments[0].texture    = drawable.texture
            
            guard
                let finalCB = _commandQueue.makeCommandBuffer(),
                let rce     = finalCB.makeRenderCommandEncoder(descriptor: rpd)
            else { return }
            finalCB.label = "final"
            
            _filterChain.renderFinalPass(withCommandEncoder: rce, flipVertically: flipVertically)
            rce.endEncoding()
            
            skipped = nil
            let inflight = _inflightSemaphore
            finalCB.addCompletedHandler { _ in
                inflight.signal()
            }
            
#if false
            if #available(macOS 10.15.4, *) {
                if _adaptiveSyncEnabled {
                    // NOTE:
                    // When a variable refresh rate display is configured with minimum and maximum
                    // refresh rates, and the game window is full-screen, we inform the variable
                    // refresh rate display about the desired frame rate of the game core to
                    // produce smooth animation.
                    //
                    // This information came from the "Optimize for variable refresh rate displays" WWDC21 talk
                    finalCB.present(drawable, afterMinimumDuration: 1.0 / gameCore.frameInterval)
                } else {
                    finalCB.present(drawable)
                }
            } else {
                finalCB.present(drawable)
            }
#else
            finalCB.present(drawable)
#endif
            
#if false
            // TODO: Add developer option to show using ImGui?
            if #available(macOS 10.15.4, *) {
                drawable.addPresentedHandler { d in
                    let dur = d.presentedTime - self.previous
                    self.frameRate = 1.0 / dur
                    self.previous = d.presentedTime
                    if d.presentedTime - self.lastLog > 1 {
                        os_log(.debug, log: .display,
                               "frame rate: %0.2f fps, interval: %0.2f Hz",
                               self.frameRate, self.gameCore.frameInterval)
                        self.lastLog = d.presentedTime
                    }
                }
            }
#endif
            finalCB.commit()
        }
    }
}

extension OpenEmuHelperApp {
    public func saveState(_ sender: Any) {
        gameCoreOwner.saveState()
    }
    
    public func loadState(_ sender: Any) {
        gameCoreOwner.loadState()
    }
    
    public func quickSave(_ sender: Any) {
        gameCoreOwner.quickSave()
    }
    
    public func quickLoad(_ sender: Any) {
        gameCoreOwner.quickLoad()
    }
    
    public func toggleFullScreen(_ sender: Any) {
        gameCoreOwner.toggleFullScreen()
    }
    
    public func toggleAudioMute(_ sender: Any) {
        gameCoreOwner.toggleAudioMute()
    }
    
    public func volumeDown(_ sender: Any) {
        gameCoreOwner.volumeDown()
    }
    
    public func volumeUp(_ sender: Any) {
        gameCoreOwner.volumeUp()
    }
    
    public func stopEmulation(_ sender: Any) {
        gameCoreOwner.stopEmulation()
    }
    
    public func resetEmulation(_ sender: Any) {
        gameCoreOwner.resetEmulation()
    }
    
    public func toggleEmulationPaused(_ sender: Any) {
        gameCoreOwner.toggleEmulationPaused()
    }
    
    public func takeScreenshot(_ sender: Any) {
        gameCoreOwner.takeScreenshot()
    }
    
    public func fastForwardGameplay(_ enable: Bool) {
        gameCoreOwner.fastForwardGameplay(enable)
    }
    
    public func rewindGameplay(_ enable: Bool) {
        // TODO: technically a data race, but it is only updating a single NSInteger
        _filterChain.frameDirection = enable ? -1 : 1
        gameCoreOwner.rewindGameplay(enable)
    }
    
    public func stepGameplayFrameForward(_ sender: Any) {
        gameCoreOwner.stepGameplayFrameForward()
    }
    
    public func stepGameplayFrameBackward(_ sender: Any) {
        gameCoreOwner.stepGameplayFrameBackward()
    }
    
    public func nextDisplayMode(_ sender: Any) {
        gameCoreOwner.nextDisplayMode()
    }
    
    public func lastDisplayMode(_ sender: Any) {
        gameCoreOwner.lastDisplayMode()
    }
}
