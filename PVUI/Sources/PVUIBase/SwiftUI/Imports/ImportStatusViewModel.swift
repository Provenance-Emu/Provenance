//
//  ImportStatusViewModel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Combine
import PVLibrary
import SwiftUI

/// ViewModel for ImportStatusView to handle state and actor isolation
@MainActor
public class ImportStatusViewModel: ObservableObject {
    @Published public var queueItems: [ImportQueueItem] = []
    @Published public var isVisible = false
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupObservers()
    }
    
    /// Sets up observers for queue changes and file recovery progress
    private func setupObservers() {
        // Define a notification name for import queue changes
        let importQueueChangedNotification = Notification.Name("ImportQueueChanged")
        
        // Observe queue changes
        NotificationCenter.default.publisher(for: importQueueChangedNotification)
            .sink { [weak self] notification in
                Task {
                    await self?.refreshQueueItems()
                }
            }
            .store(in: &cancellables)
        
        // Connect to GameImporter.shared directly
        Task {
            // Get the shared GameImporter instance
            let gameImporter = GameImporter.shared
            
            // Subscribe to its queue publisher
            gameImporter.importQueuePublisher
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    Task {
                        await self?.refreshQueueItems()
                    }
                }
                .store(in: &cancellables)
            
            // Initial refresh
            await refreshQueueItems()
        }
        
        // Observe file recovery progress
        #if !os(tvOS)
        NotificationCenter.default.publisher(for: iCloudDriveSync.iCloudFileRecoveryProgress)
            .sink { [weak self] _ in
                self?.isVisible = true
            }
            .store(in: &cancellables)
        #endif
    }
    
    /// Refresh the queue items from the game importer
    @MainActor
    public func refreshQueueItems() async {
        // Use GameImporter.shared directly
        let gameImporter = GameImporter.shared
        queueItems = await gameImporter.importQueue
        
        // Update visibility based on queue status
        isVisible = !queueItems.isEmpty
    }
}
