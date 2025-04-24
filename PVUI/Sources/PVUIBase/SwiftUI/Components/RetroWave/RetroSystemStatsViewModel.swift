//
//  RetroSystemStatsViewModel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import PVLibrary
import PVRealm
import RealmSwift

@MainActor
public final class RetroSystemStatsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// System information
    @Published public var cpuUsage: Double = 0.0
    @Published public var memoryUsed: UInt64 = 0
    @Published public var memoryTotal: UInt64 = 0
    
    /// Library statistics
    @Published public var gameCount: Int = 0
    @Published public var saveStateCount: Int = 0
    @Published public var biosCount: Int = 0
    @Published public var storageUsed: Int64 = 0
    
    /// Loading state
    @Published public var isLoading: Bool = false
    
    // MARK: - Private Properties
    
    /// Update timer
    private var updateTimer: Timer?
    
    /// Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init() {
        // Initial update
        updateSystemStats()
        updateLibraryStats()
        
        // Start timer for system stats updates
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSystemStats()
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Update all stats
    public func refreshAllStats() {
        updateSystemStats()
        updateLibraryStats()
    }
    
    // MARK: - Private Methods
    
    /// Update system statistics (CPU, memory)
    private func updateSystemStats() {
        cpuUsage = Self.cpuUsage()
        let memory = Self.memoryUsage()
        memoryUsed = memory.used
        memoryTotal = memory.total
    }
    
    /// Update library statistics (games, save states, BIOSes)
    func updateLibraryStats() {
        isLoading = true
        
        Task {
            let stats = await calculateStatsInBackground()
            
            Task { @MainActor in
                self.gameCount = stats.gameCount
                self.saveStateCount = stats.saveStateCount
                self.biosCount = stats.biosCount
                self.storageUsed = stats.totalSize
                self.isLoading = false
            }
        }
    }
    
    // Helper function to perform the potentially long-running calculations
    private func calculateStatsInBackground() async -> (gameCount: Int, saveStateCount: Int, biosCount: Int, totalSize: Int64) {
        var gameCount = 0
        var saveStateCount = 0
        var biosCount = 0
        var totalSize: Int64 = 0

        do {
            let realm = try await Realm()
            gameCount = realm.objects(PVGame.self).count
            saveStateCount = realm.objects(PVSaveState.self).count
            biosCount = realm.objects(PVBIOS.self).count

            // Calculate storage usage (expensive operation)
            
            // Get ROM sizes
            let games = realm.objects(PVGame.self)
            for game in games {
                let romPath = game.romPath
                let url = URL(fileURLWithPath: romPath)
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    if let size = attributes[.size] as? Int64 {
                        totalSize += size
                    }
                } catch {
                    WLOG("""
                             Error getting size for game "\(game.title ?? "Unknown")" 
                             at path: \(url.path). 
                             Error: \(error.localizedDescription)
                             """)
                }
                
            }
            
            // Get save state sizes
            let saveStates = realm.objects(PVSaveState.self)
            for saveState in saveStates {
                if let url = saveState.file?.url {
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                        if let size = attributes[.size] as? Int64 {
                            totalSize += size
                        }
                    } catch {
                        WLOG("""
                             Error getting size for save state at path: \(url.path). 
                             Error: \(error.localizedDescription)
                             """)
                    }
                }
            }
            
            // Get BIOS sizes
            let bioses = realm.objects(PVBIOS.self)
            for bios in bioses {
                if let url = bios.file?.url {
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                        if let size = attributes[.size] as? Int64 {
                            totalSize += size
                        }
                    } catch {
                        WLOG("""
                             Error getting size for BIOS at path: \(url.path). 
                             Error: \(error.localizedDescription)
                             """)
                    }
                }
            }

        } catch {
            ELOG("Failed to initialize Realm or calculate library stats: \(error.localizedDescription)")
            return (0, 0, 0, 0)
        }

        return (gameCount, saveStateCount, biosCount, totalSize)
    }
    
    // MARK: - Static Helper Methods
    
    /// Get CPU usage
    private static func cpuUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }
        
        if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
            for index in 0..<threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }
                
                guard infoResult == KERN_SUCCESS else {
                    break
                }
                
                let threadBasicInfo = threadInfo as thread_basic_info
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU = (totalUsageOfCPU + (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0))
                }
            }
            
            let result = vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
            if result != KERN_SUCCESS {
                DLOG("Failed to deallocate memory: \(result)")
            }
        }
        
        return totalUsageOfCPU
    }
    
    /// Get memory usage
    private static func memoryUsage() -> (used: UInt64, total: UInt64) {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        var used: UInt64 = 0
        if result == KERN_SUCCESS {
            used = UInt64(taskInfo.phys_footprint)
        }
        
        let total = ProcessInfo.processInfo.physicalMemory
        return (used, total)
    }
    
    // MARK: - Formatters
    
    /// Format bytes to human-readable size
    public func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Format memory in MB
    public func formatMemory(bytes: UInt64) -> String {
        return "\(bytes / 1024 / 1024)"
    }
}
