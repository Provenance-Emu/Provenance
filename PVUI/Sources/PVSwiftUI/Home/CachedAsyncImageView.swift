//
//  CachedAsyncImageView.swift
//  PVUI
//
//  Created by Cascade on 8/1/25.
//

import SwiftUI
import UIKit

/// High-performance cached async image view for HomeContinueItemView
/// Implements memory caching and async loading to prevent UI blocking
actor ImageCache {
    static let shared = ImageCache()
    
    private var cache: [String: UIImage] = [:]
    private var loadingTasks: [String: Task<UIImage?, Never>] = [:]
    
    private init() {}
    
    func image(for key: String) -> UIImage? {
        return cache[key]
    }
    
    func setImage(_ image: UIImage, for key: String) {
        cache[key] = image
        
        // Clean up cache if it gets too large (keep last 50 images)
        if cache.count > 50 {
            let keysToRemove = Array(cache.keys.prefix(cache.count - 40))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }
    }
    
    func loadImage(from url: URL) async -> UIImage? {
        let key = url.path
        
        // Return cached image if available
        if let cachedImage = cache[key] {
            return cachedImage
        }
        
        // Check if already loading
        if let existingTask = loadingTasks[key] {
            return await existingTask.value
        }
        
        // Create new loading task
        let task = Task<UIImage?, Never> {
            guard let image = UIImage(contentsOfFile: url.path) else {
                return nil
            }
            
            await setImage(image, for: key)
            return image
        }
        
        loadingTasks[key] = task
        let result = await task.value
        loadingTasks.removeValue(forKey: key)
        
        return result
    }
}

struct CachedAsyncImageView: View {
    let url: URL?
    let fallbackImage: UIImage
    let height: CGFloat
    let zoomFactor: CGFloat
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height * zoomFactor)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(zoomFactor)
                    .clipped()
            } else {
                Image(uiImage: fallbackImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height * zoomFactor)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(zoomFactor)
                    .clipped()
                    .opacity(isLoading ? 0.7 : 1.0)
            }
        }
        .task {
            await loadImageIfNeeded()
        }
        .onChange(of: url) { _ in
            Task {
                await loadImageIfNeeded()
            }
        }
    }
    
    private func loadImageIfNeeded() async {
        guard let url = url else { return }
        
        // Check cache first
        if let cachedImage = await ImageCache.shared.image(for: url.path) {
            await MainActor.run {
                self.loadedImage = cachedImage
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        // Load asynchronously
        let image = await ImageCache.shared.loadImage(from: url)
        
        await MainActor.run {
            self.loadedImage = image
            self.isLoading = false
        }
    }
}
