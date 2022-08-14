//
//  AudioManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 1/12/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import AVFoundation
import notify
#if canImport(AudioToolbox)
import AudioToolbox
#endif
import CoreAudio
import CoreAudioTypes

@objc
public class PVMuteSwitchMonitor: NSObject {

    public typealias MonitoringCalling = (Bool) -> ()
    
    public var isMonitoring: Bool = false
    public var isMuted: Bool = true
    
    public var notifyToken: Int32
    
    @objc
    override init() {
        self.isMonitoring = false
        self.isMuted = true
        self.notifyToken = 0
        super.init()
    }
    
    @objc
    init(isMonitoring: Bool, isMuted: Bool, notifyToken: Int32) {
        self.isMonitoring = isMonitoring
        self.isMuted = isMuted
        self.notifyToken = notifyToken
        super.init()
    }
    
    @objc
    public func startMonitoring(_ muteHandler: @escaping MonitoringCalling) {
        guard !isMonitoring else { return }
        self.isMonitoring = true
        
        let updateMutedState = { [self] in
            var state: UInt64 = 0
            let result: UInt32 = notify_get_state(notifyToken, &state)
            if result == NOTIFY_STATUS_OK {
                self.isMuted = state == 0
                muteHandler(self.isMuted)
            } else {
                ELOG("Failed to get mute state. Error: \(result)")
            }
        }
        
        notify_register_dispatch("com.apple.springboard.ringerstate", &notifyToken, .global()) { token in
            updateMutedState()
        }
                
        updateMutedState()
    }
    
    @objc
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        self.isMonitoring = false
        
        notify_cancel(self.notifyToken);
    }
}

@objc(PVAudioRendering)
public protocol AudioRendering: NSObjectProtocol
{
    var audioBuffer: RingBuffer { get }
}


internal extension AVAudioFormat
{
    var frameSize: Int {
        return Int(self.streamDescription.pointee.mBytesPerFrame)
    }
}

#if !os(macOS) && !os(watchOS)
private extension AVAudioSession
{
    func setDeltaCategory() throws
    {
        try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                                                        options: [.mixWithOthers, .allowBluetoothA2DP, .allowAirPlay])
    }
}

private extension AVAudioSessionRouteDescription
{
    var isHeadsetPluggedIn: Bool
    {
        let isHeadsetPluggedIn = self.outputs.contains { $0.portType == .headphones || $0.portType == .bluetoothA2DP }
        return isHeadsetPluggedIn
    }
    
    var isOutputtingToReceiver: Bool
    {
        let isOutputtingToReceiver = self.outputs.contains { $0.portType == .builtInReceiver }
        return isOutputtingToReceiver
    }
    
    var isOutputtingToExternalDevice: Bool
    {
        let isOutputtingToExternalDevice = self.outputs.contains { $0.portType != .builtInSpeaker && $0.portType != .builtInReceiver }
        return isOutputtingToExternalDevice
    }
}
#endif

@available(macOS 10.11, *)
@objc
public class AudioManager: NSObject, AudioRendering
{
    /// Currently only supports 16-bit interleaved Linear PCM.
    public internal(set) var audioFormat: AVAudioFormat {
        didSet {
            self.resetAudioEngine()
        }
    }
    
    public var isEnabled = true {
        didSet
        {
            self.audioBuffer.isEnabled = self.isEnabled
            
            self.updateOutputVolume()
            
            do
            {
                if self.isEnabled
                {
                    try self.audioEngine.start()
                }
                else
                {
                    self.audioEngine.pause()
                }
            }
            catch
            {
                print(error)
            }
            
            self.audioBuffer.reset()
        }
    }
    
    @objc public
    func pause() {
        isEnabled = false
//        self.audioEngine.pause()
    }
    
    public private(set) var audioBuffer: RingBuffer
    
    public internal(set) var rate = 1.0 {
        didSet {
            self.timePitchEffect.rate = Float(self.rate)
        }
    }
    
    var frameDuration: Double = (1.0 / 60.0) {
        didSet {
            guard self.audioEngine.isRunning else { return }
            self.resetAudioEngine()
        }
    }
    
    @objc public
    var volume: Float = 1.0 {
        didSet {
            self.updateOutputVolume()
        }
    }
    
    private let audioEngine: AVAudioEngine
    private let audioPlayerNode: AVAudioPlayerNode
    private let timePitchEffect: AVAudioUnitTimePitch
    
	@available(macOS 10.15, *)
	private lazy var sourceNode = self.makeSourceNode()
    
    private var audioConverter: AVAudioConverter?
    private var audioConverterRequiredFrameCount: AVAudioFrameCount?
    
    private let audioBufferCount = 3
    
    // Used to synchronize access to self.audioPlayerNode without causing deadlocks.
    private let renderingQueue = DispatchQueue(label: "com.rileytestut.Delta.AudioManager.renderingQueue")
    
    private var isMuted: Bool = false {
        didSet {
            self.updateOutputVolume()
        }
    }
    
    private let muteSwitchMonitor = PVMuteSwitchMonitor()
        
    public init(audioFormat: AVAudioFormat)
    {
        self.audioFormat = audioFormat
        
        // Temporary. Will be replaced with more accurate RingBuffer in resetAudioEngine().
        self.audioBuffer = RingBuffer(withLength: 4096)!

#if !os(macOS) && !os(watchOS)
        do
        {
            // Set category before configuring AVAudioEngine to prevent pausing any currently playing audio from another app.
            try AVAudioSession.sharedInstance().setDeltaCategory()
        }
        catch
        {
            print(error)
        }
#endif
        self.audioEngine = AVAudioEngine()
        
        self.audioPlayerNode = AVAudioPlayerNode()
        self.audioEngine.attach(self.audioPlayerNode)
        
        self.timePitchEffect = AVAudioUnitTimePitch()
        self.audioEngine.attach(self.timePitchEffect)
        
        super.init()
        
		if #available(iOS 13.0, macOS 10.15, *)
        {
            self.audioEngine.attach(self.sourceNode)
        }
        
        self.updateOutputVolume()
        
        NotificationCenter.default.addObserver(self, selector: #selector(AudioManager.resetAudioEngine), name: .AVAudioEngineConfigurationChange, object: nil)
#if !os(macOS) && !os(watchOS)
        NotificationCenter.default.addObserver(self, selector: #selector(AudioManager.resetAudioEngine), name: AVAudioSession.routeChangeNotification, object: nil)
#endif
    }
}

@available(macOS 10.11, *)
public extension AudioManager
{
    func start()
    {
        self.muteSwitchMonitor.startMonitoring { [weak self] (isMuted) in
            self?.isMuted = isMuted
        }

		#if !os(macOS) && !os(watchOS)
        do
        {
            try AVAudioSession.sharedInstance().setDeltaCategory()
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.005)
            
            if #available(iOS 13.0, *)
            {
               try AVAudioSession.sharedInstance().setAllowHapticsAndSystemSoundsDuringRecording(true)
            }
            
            try AVAudioSession.sharedInstance().setActive(true)
        }
        catch
        {
            print(error)
        }
		#endif
        self.resetAudioEngine()
    }
    
    func stop()
    {
        self.muteSwitchMonitor.stopMonitoring()
        
        self.renderingQueue.sync {
            self.audioPlayerNode.stop()
            self.audioEngine.stop()
        }
        
        self.audioBuffer.isEnabled = false
    }
}

@available(macOS 10.11, *)
private extension AudioManager
{
    func render(_ inputBuffer: AVAudioPCMBuffer, into outputBuffer: AVAudioPCMBuffer)
    {
        guard let buffer = inputBuffer.int16ChannelData, let audioConverter = self.audioConverter else { return }
        
        // Ensure any buffers from previous audio route configurations are no longer processed.
        guard inputBuffer.format == audioConverter.inputFormat && outputBuffer.format == audioConverter.outputFormat else { return }
        
        if self.audioConverterRequiredFrameCount == nil
        {
            // Determine the minimum number of input frames needed to perform a conversion.
            audioConverter.convert(to: outputBuffer, error: nil) { (requiredPacketCount, outStatus) -> AVAudioBuffer? in
                // In Linear PCM, one packet = one frame.
                self.audioConverterRequiredFrameCount = requiredPacketCount
                
                // Setting to ".noDataNow" sometimes results in crash, so we set to ".endOfStream" and reset audioConverter afterwards.
                outStatus.pointee = .endOfStream
                return nil
            }
            
            audioConverter.reset()
        }
        
        guard let audioConverterRequiredFrameCount = self.audioConverterRequiredFrameCount else { return }
        
        let availableFrameCount = AVAudioFrameCount(self.audioBuffer.availableBytesForReading / self.audioFormat.frameSize)
        if self.audioEngine.isRunning && availableFrameCount >= audioConverterRequiredFrameCount
        {            
            var conversionError: NSError?
            let status = audioConverter.convert(to: outputBuffer, error: &conversionError) { (requiredPacketCount, outStatus) -> AVAudioBuffer? in
                
                // Copy requiredPacketCount frames into inputBuffer's first channel (since audio is interleaved, no need to modify other channels).
                let maxLength = min(Int(requiredPacketCount) * self.audioFormat.frameSize, Int(inputBuffer.frameCapacity) * self.audioFormat.frameSize)
                buffer[0].withMemoryRebound(to: UInt8.self, capacity: maxLength) { (uint8Buffer) in
                    let readBytes = self.audioBuffer.read(into: uint8Buffer, maxLength: maxLength)
                    
                    let frameLength = AVAudioFrameCount(readBytes / self.audioFormat.frameSize)
                    inputBuffer.frameLength = frameLength
                }
                
                if inputBuffer.frameLength == 0
                {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                else
                {
                    outStatus.pointee = .haveData
                    return inputBuffer
                }
            }
            
            if status == .error
            {
                if let error = conversionError
                {
                    print(error, error.userInfo)
                }
            }
        }
        else
        {
            // If not running or not enough input frames, set frameLength to 0 to minimize time until we check again.
            inputBuffer.frameLength = 0
        }
        
        self.audioPlayerNode.scheduleBuffer(outputBuffer) { [weak self, weak node = audioPlayerNode] in
            guard let self = self else { return }
            
            self.renderingQueue.async {
                if node?.isPlaying == true
                {
                    self.render(inputBuffer, into: outputBuffer)
                }
            }
        }
    }

	@available(macOS 11.0, *)
    @objc func resetAudioEngine()
    {
        self.renderingQueue.sync {
            self.audioPlayerNode.reset()

			#if os(macOS)
			let avSampleRate = 44100.0
			#else
			let avSampleRate = AVAudioSession.sharedInstance().sampleRate
			#endif
			guard let outputAudioFormat = AVAudioFormat(standardFormatWithSampleRate: avSampleRate, channels: self.audioFormat.channelCount) else { return }
            
            let inputAudioBufferFrameCount = Int(self.audioFormat.sampleRate * self.frameDuration)
            let outputAudioBufferFrameCount = Int(outputAudioFormat.sampleRate * self.frameDuration)
            
            // Allocate enough space to prevent us from overwriting data before we've used it.
            let ringBufferAudioBufferCount = Int((self.audioFormat.sampleRate / outputAudioFormat.sampleRate).rounded(.up) + 10.0)
            
            let preferredBufferSize = inputAudioBufferFrameCount * self.audioFormat.frameSize * ringBufferAudioBufferCount
            guard let ringBuffer = RingBuffer(withLength: preferredBufferSize) else {
                fatalError("Cannot initialize RingBuffer with preferredBufferSize of \(preferredBufferSize)")
            }
            self.audioBuffer = ringBuffer

			let audioConverter = AVAudioConverter(from: self.audioFormat, to: outputAudioFormat)
            self.audioConverter = audioConverter
            
            self.audioConverterRequiredFrameCount = nil
            
            self.audioEngine.disconnectNodeOutput(self.timePitchEffect)
            self.audioEngine.connect(self.timePitchEffect, to: self.audioEngine.mainMixerNode, format: outputAudioFormat)

            if #available(iOS 13.0, *)
            {
                self.audioEngine.detach(self.sourceNode)
                
                self.sourceNode = self.makeSourceNode()
                self.audioEngine.attach(self.sourceNode)
                
                self.audioEngine.connect(self.sourceNode, to: self.timePitchEffect, format: outputAudioFormat)
            }
            else
            {
                self.audioEngine.disconnectNodeOutput(self.audioPlayerNode)
                self.audioEngine.connect(self.audioPlayerNode, to: self.timePitchEffect, format: outputAudioFormat)
                
                for _ in 0 ..< self.audioBufferCount
                {
                    let inputAudioBufferFrameCapacity = max(inputAudioBufferFrameCount, outputAudioBufferFrameCount)
                    
                    if let inputBuffer = AVAudioPCMBuffer(pcmFormat: self.audioFormat, frameCapacity: AVAudioFrameCount(inputAudioBufferFrameCapacity)),
                        let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputAudioFormat, frameCapacity: AVAudioFrameCount(outputAudioBufferFrameCount))
                    {
                        self.render(inputBuffer, into: outputBuffer)
                    }
                }
            }
            #if !os(tvOS) && !os(macOS)
            do
            {
                // Explicitly set output port since .defaultToSpeaker option pauses external audio.
                if AVAudioSession.sharedInstance().currentRoute.isOutputtingToReceiver
                {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                }
                
                try self.audioEngine.start()
                
                if #available(iOS 13.0, *) {}
                else
                {
                    self.audioPlayerNode.play()
                }
            }
            catch
            {
                print(error)
            }
            #endif
        }
    }
    
    @objc func updateOutputVolume()
    {
        if !self.isEnabled
        {
            self.audioEngine.mainMixerNode.outputVolume = 0.0
        }
        else
		{
			#if os(macOS)
			if self.isMuted
			{
				// Mute if playing through speaker or headphones.
				self.audioEngine.mainMixerNode.outputVolume = 0.0
			}
			else
			{
				// Ignore mute switch for other audio routes (e.g. AirPlay).
				self.audioEngine.mainMixerNode.outputVolume = volume
			}
			#else
            let route = AVAudioSession.sharedInstance().currentRoute
            if self.isMuted && (route.isHeadsetPluggedIn || !route.isOutputtingToExternalDevice)
            {
                // Mute if playing through speaker or headphones.
                self.audioEngine.mainMixerNode.outputVolume = 0.0
            }
            else
            {
                // Ignore mute switch for other audio routes (e.g. AirPlay).
                self.audioEngine.mainMixerNode.outputVolume = volume
            }
			#endif
        }
    }
        
	@available(macOS 10.15, *)
	func makeSourceNode() -> AVAudioSourceNode {
        var isPrimed = false
        var previousSampleCount: Int?
        
        // Accessing AVAudioSession.sharedInstance() from render block may cause audio glitches,
        // so calculate sampleRateRatio now rather than later when needed 🤷‍♂️
		#if os(macOS)
		let avSampleRate = 44100.0
		#else
		let avSampleRate = AVAudioSession.sharedInstance().sampleRate
		#endif
        let sampleRateRatio = (self.audioFormat.sampleRate / avSampleRate).rounded(.up)
        
        let sourceNode = AVAudioSourceNode(format: self.audioFormat) { [audioFormat, audioBuffer] (_, _, frameCount, audioBufferList) -> OSStatus in
            defer { previousSampleCount = audioBuffer.availableBytesForReading }
            
            let unsafeAudioBufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = unsafeAudioBufferList[0].mData else { return kAudioFileStreamError_UnspecifiedError }
            
            let requestedBytes = Int(frameCount) * audioFormat.frameSize
            
            if !isPrimed
            {
                // Make sure audio buffer has enough initial samples to prevent audio distortion.
                
                guard audioBuffer.availableBytesForReading >= requestedBytes * Int(sampleRateRatio) else { return kAudioFileStreamError_DataUnavailable }
                isPrimed = true
            }
            
            if let previousSampleCount = previousSampleCount, audioBuffer.availableBytesForReading < previousSampleCount
            {
                // Audio buffer has been reset, so we need to prime it again.
                
                isPrimed = false
                return kAudioFileStreamError_DataUnavailable
            }
            
            guard audioBuffer.availableBytesForReading >= requestedBytes else {
                isPrimed = false
                return kAudioFileStreamError_DataUnavailable
            }
                        
            let readBytes = audioBuffer.read(into: buffer, maxLength: requestedBytes)
            unsafeAudioBufferList[0].mDataByteSize = UInt32(readBytes)
            
            return noErr
        }
        
        return sourceNode
    }
}
