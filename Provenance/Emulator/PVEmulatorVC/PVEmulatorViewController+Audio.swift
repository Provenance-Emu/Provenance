// MARK: - PVAudioDelegate
import PVEmulatorCore

extension PVEmulatorViewController {
    func audioSampleRateDidChange() {
        gameAudio.stop()
        gameAudio.start()
    }
}
