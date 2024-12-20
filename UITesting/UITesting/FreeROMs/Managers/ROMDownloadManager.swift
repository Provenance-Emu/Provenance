import Foundation
import PVLogging

/// Manages concurrent downloads of ROMs
class ROMDownloadManager: ObservableObject {
    /// Maximum number of concurrent downloads
    private let maxConcurrentDownloads = 3

    /// Active downloads
    @Published private(set) var activeDownloads: [String: DownloadStatus] = [:]

    /// Queue of pending downloads
    private var downloadQueue: [(ROM, URL, (Result<URL, Error>) -> Void)] = []

    /// Semaphore to control concurrent downloads
    private let semaphore = DispatchSemaphore(value: 3)

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

        // Add to queue if at max concurrent downloads
        if activeDownloads.count >= maxConcurrentDownloads {
            downloadQueue.append((rom, url, completion))
            return
        }

        startDownload(rom: rom, from: url, completion: completion)
    }

    private func startDownload(rom: ROM, from url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        DLOG("Starting download of \(rom.id) at \(url.absoluteString)")
        
        let downloadTask = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            defer {
                self?.semaphore.signal()
                self?.processNextDownload()
            }

            if let error = error {
                DispatchQueue.main.async {
                    self?.activeDownloads[rom.id] = .failed(error: .networkError(error))
                }
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                let error = DownloadStatus.DownloadError.invalidResponse(httpResponse.statusCode)
                DispatchQueue.main.async {
                    self?.activeDownloads[rom.id] = .failed(error: error)
                }
                completion(.failure(error))
                return
            }

            guard let tempURL = tempURL else {
                let error = DownloadStatus.DownloadError.noData
                DispatchQueue.main.async {
                    self?.activeDownloads[rom.id] = .failed(error: error)
                }
                completion(.failure(error))
                return
            }

            DispatchQueue.main.async {
                self?.activeDownloads[rom.id] = .completed(localURL: tempURL)
            }
            completion(.success(tempURL))
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
        activeDownloads[rom.id] = .downloading(progress: 0.0)
    }

    private func processNextDownload() {
        guard !downloadQueue.isEmpty else { return }

        let next = downloadQueue.removeFirst()
        startDownload(rom: next.0, from: next.1, completion: next.2)
    }

    /// Set download error state
    func setError(_ error: DownloadStatus.DownloadError, for romId: String) {
        activeDownloads[romId] = .failed(error: error)
    }
}
