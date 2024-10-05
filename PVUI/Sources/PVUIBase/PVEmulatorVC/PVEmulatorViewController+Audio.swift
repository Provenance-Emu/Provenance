// MARK: - PVAudioDelegate

public
extension PVEmulatorViewController {
    func audioSampleRateDidChange() {
        gameAudio.stopAudio()
        
        try? gameAudio.startAudio()
    }
}
