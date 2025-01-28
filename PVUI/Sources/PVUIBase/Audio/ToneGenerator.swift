import AVFoundation
import PVLogging

/// Generates synthesized tones for button presses
public final class ToneGenerator {
    private var audioEngine: AVAudioEngine
    private var tonePlayer: AVAudioPlayerNode
    private var reverbNode: AVAudioUnitReverb
    private var toneBuffer: AVAudioPCMBuffer?

    /// Initialize tone generator with audio engine setup
    init() {
        audioEngine = AVAudioEngine()
        tonePlayer = AVAudioPlayerNode()
        reverbNode = AVAudioUnitReverb()
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        // Attach nodes
        audioEngine.attach(tonePlayer)
        audioEngine.attach(reverbNode)

        // Set reverb preset and wet/dry mix
        reverbNode.loadFactoryPreset(.smallRoom)
        reverbNode.wetDryMix = 15 // Subtle reverb

        // Connect nodes
        let format = createToneFormat()
        audioEngine.connect(tonePlayer, to: reverbNode, format: format)
        audioEngine.connect(reverbNode, to: audioEngine.mainMixerNode, format: format)

        do {
            try audioEngine.start()
        } catch {
            ELOG("Failed to start tone generator: \(error)")
        }
    }

    private func createToneFormat() -> AVAudioFormat {
        return AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    }

    /// Play a button press tone with optional panning
    func playButtonPressTone(pan: Float = 0, volume: Float = 1.0) {
        let sampleRate: Float = 44100
        let duration: Float = 0.02 // Shorter duration for click
        let numSamples = Int(duration * sampleRate)

        // Create stereo buffer
        guard let buffer = AVAudioPCMBuffer(pcmFormat: createToneFormat(),
                                          frameCapacity: AVAudioFrameCount(numSamples)) else {
            return
        }
        buffer.frameLength = buffer.frameCapacity

        // Generate samples for both channels
        let leftGain: Float = (1.0 - pan) * volume
        let rightGain: Float = (1.0 + pan) * volume

        // Click parameters
        let clickFreq: Float = 9600.0 * pow(volume, 1 / volume) // Higher frequency for click
        let subFreq: Float = clickFreq * 0.5 // Sub-harmonic at half frequency
        let noiseAmount: Float = 0.04 // Amount of noise to mix in
        let decayFactor: Float = 16.0 // Faster decay for sharp click
        let subDecayFactor: Float = decayFactor * 0.7 // Slightly longer decay for sub
        let subAmount: Float = 0.3 // Amount of sub to mix in

        // Wave shape interpolation - volume controls sine vs ramp mix
        let rampness = volume // 0 = pure sine, 1 = pure ramp

        for frame in 0..<numSamples {
            let time = Float(frame) / sampleRate

            // Generate main click tone with quick decay
            let envelope = expf(-time * decayFactor)
            let subEnvelope = expf(-time * subDecayFactor)

            // Generate both sine and ramp waves for main tone
            let phase = clickFreq * time
            let sineTone = sinf(2.0 * .pi * phase)
            let rampPhase = phase.truncatingRemainder(dividingBy: 1.0)
            let rampTone = (2.0 * rampPhase - 1.0)

            // Generate sub-harmonic tone (pure sine for smoother bass)
            let subTone = sinf(2.0 * .pi * subFreq * time)

            // Interpolate between sine and ramp based on volume
            let tone = (1.0 - rampness) * sineTone + rampness * rampTone

            // Generate noise component
            let noise = (Float(arc4random_uniform(1000)) / 500.0 - 1.0)

            // Combine all components with their envelopes
            let mainComponent = envelope * ((1.0 - noiseAmount) * tone + noiseAmount * noise)
            let subComponent = subEnvelope * subTone * subAmount

            let value = mainComponent + subComponent

            // Apply stereo panning
            buffer.floatChannelData?[0][frame] = value * leftGain
            buffer.floatChannelData?[1][frame] = value * rightGain
        }

        // Schedule and play the buffer
        tonePlayer.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        tonePlayer.play()
    }
}
