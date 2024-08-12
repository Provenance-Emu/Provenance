// MARK: - PVAudioDelegate

public
extension PVEmulatorViewController {
    func audioSampleRateDidChange() {
        gameAudio.stopAudio()
        gameAudio.startAudio()
    }
}
