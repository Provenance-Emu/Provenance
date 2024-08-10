// MARK: - PVAudioDelegate

extension PVEmulatorViewController {
    func audioSampleRateDidChange() {
        gameAudio.stopAudio()
        gameAudio.startAudio()
    }
}
