import Foundation
import PVLogging

/// Manages concurrent downloads of ROMs
class ROMDownloadManager: ObservableObject {
    /// Maximum number of concurrent downloads
    private let maxConcurrentDownloads = 3

    /// Active downloads
    @Published private(set) var activeDownloads: [String: DownloadStatus] = [:]

    /// Queue of pending downloads
    private var pendingDownloads: [(ROM, URL, (Result<URL, Error>) -> Void)] = []

    /// Semaphore to control concurrent downloads
    private let semaphore = DispatchSemaphore(value: 3)

    /// Queue for managing download operations
    private let downloadQueue = DispatchQueue(label: "com.provenance.downloads", qos: .userInitiated)

    enum DownloadStatus {
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

    private var observations = Set<NSKeyValueObservation>()

    /// Start downloading a ROM
    func download(rom: ROM, from url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        guard activeDownloads[rom.id] == nil else { return }

        downloadQueue.async { [weak self] in
            guard let self = self else { return }

            // Wait for a semaphore slot
            self.semaphore.wait()

            DispatchQueue.main.async {
                self.activeDownloads[rom.id] = .downloading(progress: 0.0)
            }

            self.startDownload(rom: rom, from: url) { result in
                // Signal semaphore after download completes
                self.semaphore.signal()

                DispatchQueue.main.async {
                    // Process next download if any
                    if !self.pendingDownloads.isEmpty {
                        let next = self.pendingDownloads.removeFirst()
                        self.download(rom: next.0, from: next.1, completion: next.2)
                    }
                }

                completion(result)
            }
        }
    }

    private func startDownload(rom: ROM, from url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        DLOG("Starting download of \(rom.id) at \(url.absoluteString)")

        let downloadTask = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.activeDownloads[rom.id] = .failed(error: .networkError(error))
                }
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                let error = DownloadStatus.DownloadError.invalidResponse(httpResponse.statusCode)
                DispatchQueue.main.async {
                    self.activeDownloads[rom.id] = .failed(error: error)
                }
                completion(.failure(error))
                return
            }

            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    self.activeDownloads[rom.id] = .failed(error: .noData)
                }
                completion(.failure(DownloadStatus.DownloadError.noData))
                return
            }

            // Create a new temporary URL with the correct filename
            let tempDir = FileManager.default.temporaryDirectory
            let destinationURL = tempDir.appendingPathComponent(rom.file)

            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                DispatchQueue.main.async {
                    self.activeDownloads[rom.id] = .completed(localURL: destinationURL)
                }
                completion(.success(destinationURL))
            } catch {
                DispatchQueue.main.async {
                    self.activeDownloads[rom.id] = .failed(error: .networkError(error))
                }
                completion(.failure(error))
            }
        }

        // Observe download progress
        let observation = downloadTask.progress.observe(
            \.fractionCompleted,
            options: [.new],
            changeHandler: { [weak self] (progress: Progress, _) in
                DispatchQueue.main.async {
                    self?.activeDownloads[rom.id] = .downloading(progress: progress.fractionCompleted)
                }
            }
        )
        observations.insert(observation)

        downloadTask.resume()
    }

    /// Set download error state
    func setError(_ error: DownloadStatus.DownloadError, for romId: String) {
        activeDownloads[romId] = .failed(error: error)
    }
}
