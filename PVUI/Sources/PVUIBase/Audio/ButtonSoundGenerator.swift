import Foundation
import AVFoundation
import PVLogging
import PVSettings

/// Generates button press sound effects
public final class ButtonSoundGenerator {
    public static let shared = ButtonSoundGenerator()

    private var audioEngine: AVAudioEngine
    private var players: [ButtonSound: AVAudioPlayerNode] = [:]
    private var pressBuffers: [ButtonSound: AVAudioPCMBuffer] = [:]
    private var releaseBuffers: [ButtonSound: AVAudioPCMBuffer] = [:]
    private let toneGenerator: ToneGenerator

    private init() {
        audioEngine = AVAudioEngine()
        toneGenerator = ToneGenerator()
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        // Load and prepare all sound buffers
        for sound in ButtonSound.allCases where sound != .none {
            guard let url = Bundle.module.url(forResource: sound.filename,
                                            withExtension: "wav",
                                            subdirectory: "Sounds/ButtonSounds"),
                  let file = try? AVAudioFile(forReading: url) else {
                ELOG("Failed to load sound file: \(sound.filename).wav")
                continue
            }

            let player = AVAudioPlayerNode()
            audioEngine.attach(player)
            audioEngine.connect(player, to: audioEngine.mainMixerNode, format: file.processingFormat)

            // Create full buffer
            guard let fullBuffer = try? AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                        frameCapacity: AVAudioFrameCount(file.length)) else {
                ELOG("Failed to create buffer for sound: \(sound.filename)")
                continue
            }

            // Load the file data into the buffer
            do {
                try file.read(into: fullBuffer)
            } catch {
                ELOG("Failed to read sound file into buffer: \(error)")
                continue
            }

            players[sound] = player

            // Split and trim buffer if sound has release sample
            if sound.hasReleaseSample {
                let halfFrames = fullBuffer.frameLength / 2

                // Create press buffer (first half)
                if let pressBuffer = createTrimmedBuffer(from: fullBuffer, start: 0, length: halfFrames) {
                    pressBuffers[sound] = pressBuffer
                }

                // Create release buffer (second half)
                if let releaseBuffer = createTrimmedBuffer(from: fullBuffer, start: AVAudioFramePosition(halfFrames), length: halfFrames) {
                    releaseBuffers[sound] = releaseBuffer
                }
            } else {
                // Store trimmed buffer as press buffer if no release sample
                if let trimmedBuffer = createTrimmedBuffer(from: fullBuffer, start: 0, length: fullBuffer.frameLength) {
                    pressBuffers[sound] = trimmedBuffer
                }
            }
        }

        // Start engine
        do {
            try audioEngine.start()
        } catch {
            ELOG("Failed to start audio engine: \(error)")
        }
    }

    private func createTrimmedBuffer(from buffer: AVAudioPCMBuffer, start: AVAudioFramePosition, length: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard let srcData = buffer.floatChannelData else { return nil }

        // Find start of actual audio (threshold for "silence")
        let threshold: Float = 0.001 // Adjust this value to tune silence detection
        var firstNonSilentFrame = start
        let channelCount = Int(buffer.format.channelCount)
        let endFrame = start + AVAudioFramePosition(length)

        // Look for first frame where any channel exceeds threshold
        outerLoop: for frame in start..<endFrame {
            for channel in 0..<channelCount {
                let sample = abs(srcData[channel][Int(frame)])
                if sample > threshold {
                    firstNonSilentFrame = frame
                    break outerLoop
                }
            }
        }

        // Calculate new buffer length
        let newLength = AVAudioFrameCount(endFrame - firstNonSilentFrame)
        guard newLength > 0,
              let trimmedBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: newLength) else {
            return nil
        }

        trimmedBuffer.frameLength = newLength

        // Copy the trimmed data
        guard let dstData = trimmedBuffer.floatChannelData else { return nil }
        for channel in 0..<channelCount {
            let src = srcData[channel].advanced(by: Int(firstNonSilentFrame))
            let dst = dstData[channel]
            dst.assign(from: src, count: Int(newLength))
        }

        return trimmedBuffer
    }

    /// Play a specific sound effect with optional panning and volume
    public func playSound(_ sound: ButtonSound, pan: Float = 0, volume: Float = 1.0) {
        switch sound {
        case .none:
            return
        case .generated:
            toneGenerator.playButtonPressTone(pan: pan, volume: volume)
        default:
            playPressSound(sound, pan: pan, volume: volume)
        }
    }

    /// Play the appropriate sound based on settings with optional panning and volume
    public func playButtonPressSound(pan: Float = 0, volume: Float = 1.0) {
        let soundType = Defaults[.buttonSound]
        playSound(soundType, pan: pan, volume: volume)
    }

    /// Play the release sound if available
    public func playButtonReleaseSound(sound: ButtonSound, pan: Float = 0, volume: Float = 1.0) {
        guard sound.hasReleaseSample,
              let player = players[sound],
              let buffer = releaseBuffers[sound] else { return }

        player.pan = pan
        player.volume = volume
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }

    private func playPressSound(_ sound: ButtonSound, pan: Float = 0, volume: Float = 1.0) {
        guard sound != .none && sound != .generated,
              let player = players[sound],
              let buffer = pressBuffers[sound] else { return }

        player.pan = pan
        player.volume = volume
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }
}
