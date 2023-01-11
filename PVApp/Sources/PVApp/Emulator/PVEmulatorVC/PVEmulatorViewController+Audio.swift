// MARK: - PVAudioDelegate

extension PVEmulatorViewController {
    func audioSampleRateDidChange() {
        gameAudio.stop()
        gameAudio.start()
    }
}
