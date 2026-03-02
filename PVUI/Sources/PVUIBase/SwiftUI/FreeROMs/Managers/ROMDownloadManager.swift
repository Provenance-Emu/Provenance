import Foundation
import PVLogging

/// Manages concurrent ROM downloads with a bounded queue
class ROMDownloadManager: ObservableObject {
    /// Maximum number of concurrent downloads
    private let maxConcurrent = 3

    @Published private(set) var activeDownloads: [String: DownloadStatus] = [:]

    private var runningCount = 0
    private var queue: [(rom: ROM, url: URL, onComplete: (Result<URL, Error>) -> Void)] = []
    private var observations: [String: NSKeyValueObservation] = [:]

    enum DownloadStatus {
        case queued
        case downloading(progress: Double)
        case completed(localURL: URL)
        case failed(error: DownloadError)

        enum DownloadError: LocalizedError {
            case networkError(Error)
            case invalidResponse(Int)
            case noData
            case invalidURL

            var errorDescription: String? {
                switch self {
                case .networkError(let error):
                    return "Network error: \(error.localizedDescription)"
                case .invalidResponse(let code):
                    return "Server error (HTTP \(code))"
                case .noData:
                    return "No data received"
                case .invalidURL:
                    return "Invalid download URL"
                }
            }
        }
    }

    /// Enqueue a ROM for download
    func download(rom: ROM, from url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        guard activeDownloads[rom.id] == nil else { return }

        activeDownloads[rom.id] = .queued
        queue.append((rom: rom, url: url, onComplete: completion))
        drainQueue()
    }

    /// Start queued downloads up to the concurrency limit
    private func drainQueue() {
        while runningCount < maxConcurrent, !queue.isEmpty {
            let item = queue.removeFirst()
            runningCount += 1
            startDownload(rom: item.rom, from: item.url, completion: item.onComplete)
        }
    }

    private func downloadDidFinish() {
        runningCount -= 1
        drainQueue()
    }

    private func startDownload(rom: ROM, from url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        DLOG("Starting download of \(rom.id) at \(url.absoluteString)")

        activeDownloads[rom.id] = .downloading(progress: 0.0)

        let downloadTask = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.observations.removeValue(forKey: rom.id)
                    self.activeDownloads[rom.id] = .failed(error: .networkError(error))
                    completion(.failure(error))
                    self.downloadDidFinish()
                }
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                let dlError = DownloadStatus.DownloadError.invalidResponse(httpResponse.statusCode)
                DispatchQueue.main.async {
                    self.observations.removeValue(forKey: rom.id)
                    self.activeDownloads[rom.id] = .failed(error: dlError)
                    completion(.failure(dlError))
                    self.downloadDidFinish()
                }
                return
            }

            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    self.observations.removeValue(forKey: rom.id)
                    self.activeDownloads[rom.id] = .failed(error: .noData)
                    completion(.failure(DownloadStatus.DownloadError.noData))
                    self.downloadDidFinish()
                }
                return
            }

            // Move file immediately -- tempURL is only valid for the duration of this callback
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "_" + rom.file)

            do {
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                DispatchQueue.main.async {
                    self.observations.removeValue(forKey: rom.id)
                    self.activeDownloads[rom.id] = .completed(localURL: destinationURL)
                    completion(.success(destinationURL))
                    self.downloadDidFinish()
                }
            } catch {
                DispatchQueue.main.async {
                    self.observations.removeValue(forKey: rom.id)
                    self.activeDownloads[rom.id] = .failed(error: .networkError(error))
                    completion(.failure(error))
                    self.downloadDidFinish()
                }
            }
        }

        let observation = downloadTask.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            DispatchQueue.main.async {
                if case .downloading = self?.activeDownloads[rom.id] {
                    self?.activeDownloads[rom.id] = .downloading(progress: progress.fractionCompleted)
                }
            }
        }
        observations[rom.id] = observation

        downloadTask.resume()
    }

    /// Set download error state
    func setError(_ error: DownloadStatus.DownloadError, for romId: String) {
        activeDownloads[romId] = .failed(error: error)
    }
}
