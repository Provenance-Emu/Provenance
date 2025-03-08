#if canImport(UIKit)
import UIKit

/// Extension to support prefetching for UICollectionView
public extension PVMediaCache {
    /// A prefetching controller that can be used with UICollectionViewDataSourcePrefetching
    class PrefetchingController: NSObject, UICollectionViewDataSourcePrefetching {
        /// The media cache instance
        private let mediaCache: PVMediaCache

        /// A closure that returns the image key for a given index path
        private let keyProvider: (IndexPath) -> String?

        /// Currently active prefetch operations
        private var prefetchOperations: [IndexPath: BlockOperation] = [:]

        /// Initialize with a media cache and key provider
        /// - Parameters:
        ///   - mediaCache: The media cache instance to use
        ///   - keyProvider: A closure that returns the image key for a given index path
        public init(mediaCache: PVMediaCache, keyProvider: @escaping (IndexPath) -> String?) {
            self.mediaCache = mediaCache
            self.keyProvider = keyProvider
            super.init()
        }

        /// UICollectionViewDataSourcePrefetching implementation
        public func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
            /// Filter out index paths that already have operations
            let newIndexPaths = indexPaths.filter { !prefetchOperations.keys.contains($0) }

            for indexPath in newIndexPaths {
                guard let key = keyProvider(indexPath), !key.isEmpty else { continue }

                /// Create and store the operation
                let operation = mediaCache.image(forKey: key) { [weak self] _, _ in
                    /// Remove the operation when complete
                    DispatchQueue.main.async {
                        self?.prefetchOperations.removeValue(forKey: indexPath)
                    }
                }

                if let operation = operation {
                    prefetchOperations[indexPath] = operation
                }
            }
        }

        /// UICollectionViewDataSourcePrefetching implementation
        public func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
            for indexPath in indexPaths {
                /// Cancel and remove the operation
                prefetchOperations[indexPath]?.cancel()
                prefetchOperations.removeValue(forKey: indexPath)
            }
        }

        /// Cancel all prefetch operations
        public func cancelAllPrefetching() {
            for operation in prefetchOperations.values {
                operation.cancel()
            }
            prefetchOperations.removeAll()
        }
    }

    /// Create a prefetching controller for a collection view
    /// - Parameter keyProvider: A closure that returns the image key for a given index path
    /// - Returns: A prefetching controller that can be assigned to a collection view
    func createPrefetchingController(keyProvider: @escaping (IndexPath) -> String?) -> PrefetchingController {
        return PrefetchingController(mediaCache: self, keyProvider: keyProvider)
    }
}
#endif
