#if !os(macOS)
import AVFoundation
import MediaPlayer

extension AVAudioSession {
    /// Returns true if the device is in silent mode (hardware silent switch is on)
    var isSilentModeEnabled: Bool {
        // Use the ringer state to detect silent mode
        return self.currentRoute.outputs.contains {
            $0.portType == .builtInSpeaker
        } && self.secondaryAudioShouldBeSilencedHint
    }
}

extension AVAudioSessionRouteDescription {
    var isHeadsetPluggedIn: Bool {
        return self.outputs.contains {
            $0.portType == .headphones ||
            $0.portType == .bluetoothA2DP ||
            $0.portType == .bluetoothHFP
        }
    }

    var isOutputtingToReceiver: Bool {
        return self.outputs.contains { $0.portType == .builtInReceiver }
    }

    var isOutputtingToExternalDevice: Bool {
        return self.outputs.contains {
            $0.portType != .builtInSpeaker &&
            $0.portType != .builtInReceiver
        }
    }
}
#endif
