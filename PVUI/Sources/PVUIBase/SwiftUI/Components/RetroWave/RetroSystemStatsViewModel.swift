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

    /// Device information
    @Published public var deviceModel: String = ""
    @Published public var cpuModel: String = ""
    @Published public var gpuModel: String = ""
    @Published public var osVersion: String = ""
    @Published public var cpuCoreCount: Int = 0

    /// Library statistics
    @Published public var gameCount: Int = 0
    @Published public var saveStateCount: Int = 0
    @Published public var biosCount: Int = 0
    @Published public var storageUsed: Int64 = 0
    @Published public var totalPlaytime: Int = 0 // Total playtime in seconds

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
        updateDeviceInfo()

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

    /// Update device information (one-time setup)
    private func updateDeviceInfo() {
        deviceModel = Self.deviceModel()
        cpuModel = Self.cpuModel()
        gpuModel = Self.gpuModel()
        osVersion = Self.osVersion()
        cpuCoreCount = Self.cpuCoreCount()
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
                self.totalPlaytime = stats.totalPlaytime
                self.isLoading = false
            }
        }
    }

    // Helper function to perform the potentially long-running calculations
    private func calculateStatsInBackground() async -> (gameCount: Int, saveStateCount: Int, biosCount: Int, totalSize: Int64, totalPlaytime: Int) {
        var gameCount = 0
        var saveStateCount = 0
        var biosCount = 0
        var totalSize: Int64 = 0
        var totalPlaytime: Int = 0

        do {
            let realm = try await Realm()
            gameCount = realm.objects(PVGame.self).count
            saveStateCount = realm.objects(PVSaveState.self).count

            // Count only BIOS entries that have a file on disk
            let bioses = realm.objects(PVBIOS.self)
            biosCount = bioses.filter { $0.file?.url != nil }.count

            // Calculate storage usage (expensive operation)

            // Get ROM sizes and total playtime
            let games = realm.objects(PVGame.self)
            for game in games {
                // Sum up playtime for all games
                totalPlaytime += game.timeSpentInGame
                // Get the correct file URL using the game's file property
                guard let file = game.file, let fileURL = file.url else {
                    WLOG("ROM has no valid file: \(game.title ?? "Unknown") (\(game.md5Hash ?? "No MD5"))")
                    continue
                }

                // Use the file's URL which should have the correct path including the ROMs subfolder
                let url = fileURL
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

            // Get BIOS sizes (reuse bioses from count calculation)
            for bios in bioses {
                if let url = bios.file?.url {
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                        if let size = attributes[FileAttributeKey.size] as? Int64 {
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
            return (0, 0, 0, 0, 0)
        }

        return (gameCount, saveStateCount, biosCount, totalSize, totalPlaytime)
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

    /// Get device model
    private static func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        // Map device identifiers to human-readable names
        switch identifier {
        // iPhone models (iOS 15+ compatible)
        // iPhone 6s series (iOS 15 minimum supported)
        case "iPhone8,1": return "iPhone 6s"
        case "iPhone8,2": return "iPhone 6s Plus"
        // iPhone SE (1st generation)
        case "iPhone8,4": return "iPhone SE (1st generation)"
        // iPhone 7 series
        case "iPhone9,1", "iPhone9,3": return "iPhone 7"
        case "iPhone9,2", "iPhone9,4": return "iPhone 7 Plus"
        // iPhone 8 series
        case "iPhone10,1", "iPhone10,4": return "iPhone 8"
        case "iPhone10,2", "iPhone10,5": return "iPhone 8 Plus"
        // iPhone X
        case "iPhone10,3", "iPhone10,6": return "iPhone X"
        // iPhone XS series
        case "iPhone11,2": return "iPhone XS"
        case "iPhone11,4", "iPhone11,6": return "iPhone XS Max"
        case "iPhone11,8": return "iPhone XR"
        // iPhone 11 series
        case "iPhone12,1": return "iPhone 11"
        case "iPhone12,3": return "iPhone 11 Pro"
        case "iPhone12,5": return "iPhone 11 Pro Max"
        // iPhone SE (2nd generation)
        case "iPhone12,8": return "iPhone SE (2nd generation)"
        // iPhone 12 series
        case "iPhone13,1": return "iPhone 12 mini"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"
        // iPhone 13 series
        case "iPhone14,7": return "iPhone 13 mini"
        case "iPhone14,8": return "iPhone 13"
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        // iPhone SE (3rd generation)
        case "iPhone14,6": return "iPhone SE (3rd generation)"
        // iPhone 14 series
        case "iPhone15,4": return "iPhone 14"
        case "iPhone15,5": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        // iPhone 15 series
        case "iPhone16,1": return "iPhone 15"
        case "iPhone16,2": return "iPhone 15 Plus"
        case "iPhone16,3": return "iPhone 15 Pro"
        case "iPhone16,4": return "iPhone 15 Pro Max"
        // iPhone 16 series
        case "iPhone17,1": return "iPhone 16"
        case "iPhone17,2": return "iPhone 16 Plus"
        case "iPhone17,3": return "iPhone 16 Pro"
        case "iPhone17,4": return "iPhone 16 Pro Max"

        // iPod touch models (iOS 15+ compatible)
        case "iPod9,1": return "iPod touch (7th generation)"

        // iPad models (iOS 15+ compatible)
        // iPad (6th generation and newer)
        case "iPad7,5", "iPad7,6": return "iPad (6th generation)"
        case "iPad7,11", "iPad7,12": return "iPad (7th generation)"
        case "iPad11,6", "iPad11,7": return "iPad (8th generation)"
        case "iPad12,1", "iPad12,2": return "iPad (9th generation)"
        case "iPad13,18", "iPad13,19": return "iPad (10th generation)"
        case "iPad14,10", "iPad14,11": return "iPad (11th generation)"

        // iPad Air (3rd generation and newer)
        case "iPad11,3", "iPad11,4": return "iPad Air (3rd generation)"
        case "iPad13,1", "iPad13,2": return "iPad Air (4th generation)"
        case "iPad14,3", "iPad14,4": return "iPad Air (5th generation)"
        case "iPad14,8", "iPad14,9": return "iPad Air (6th generation)"

        // iPad mini (5th generation and newer)
        case "iPad11,1", "iPad11,2": return "iPad mini (5th generation)"
        case "iPad14,1", "iPad14,2": return "iPad mini (6th generation)"

        // iPad Pro models (iOS 15+ compatible)
        // iPad Pro 9.7-inch
        case "iPad6,3", "iPad6,4": return "iPad Pro 9.7-inch"
        // iPad Pro 10.5-inch
        case "iPad7,3", "iPad7,4": return "iPad Pro 10.5-inch"
        // iPad Pro 12.9-inch (1st generation)
        case "iPad6,7", "iPad6,8": return "iPad Pro 12.9-inch (1st generation)"
        // iPad Pro 12.9-inch (2nd generation)
        case "iPad7,1", "iPad7,2": return "iPad Pro 12.9-inch (2nd generation)"
        // iPad Pro 11-inch (1st generation)
        case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4": return "iPad Pro 11-inch (1st generation)"
        // iPad Pro 12.9-inch (3rd generation)
        case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8": return "iPad Pro 12.9-inch (3rd generation)"
        // iPad Pro 11-inch (2nd generation)
        case "iPad8,9", "iPad8,10": return "iPad Pro 11-inch (2nd generation)"
        // iPad Pro 12.9-inch (4th generation)
        case "iPad8,11", "iPad8,12": return "iPad Pro 12.9-inch (4th generation)"
        // iPad Pro 11-inch (3rd generation)
        case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7": return "iPad Pro 11-inch (3rd generation)"
        // iPad Pro 12.9-inch (5th generation)
        case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": return "iPad Pro 12.9-inch (5th generation)"
        // iPad Pro 11-inch (4th generation)
        case "iPad14,5", "iPad14,6": return "iPad Pro 11-inch (4th generation)"
        // iPad Pro 12.9-inch (6th generation)
        case "iPad14,10", "iPad14,11": return "iPad Pro 12.9-inch (6th generation)"

        // Apple TV models (tvOS 15+ compatible)
        case "AppleTV5,3": return "Apple TV HD (4th generation)"
        case "AppleTV6,2": return "Apple TV 4K (1st generation)"
        case "AppleTV11,1": return "Apple TV 4K (2nd generation)"
        case "AppleTV14,1": return "Apple TV 4K (3rd generation)"

        // Mac models (for Mac Catalyst)
        case let identifier where identifier.hasPrefix("MacBookAir"): return "MacBook Air"
        case let identifier where identifier.hasPrefix("MacBookPro"): return "MacBook Pro"
        case let identifier where identifier.hasPrefix("iMac"): return "iMac"
        case let identifier where identifier.hasPrefix("Mac"): return "Mac"

        // Simulator
        case "x86_64", "arm64": return "Simulator"

        default: return identifier
        }
    }

    /// Get CPU model information
    private static func cpuModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        // Map device identifiers to CPU models
        switch identifier {
        // A9 (iPhone 6s series, iPhone SE 1st gen, iPad Pro 9.7", iPad 5th gen)
        case "iPhone8,1", "iPhone8,2", "iPhone8,4": return "A9"
        case "iPad6,3", "iPad6,4", "iPad6,7", "iPad6,8": return "A9X"

        // A10 (iPhone 7 series, iPod touch 7th gen, iPad 6th/7th gen)
        case "iPhone9,1", "iPhone9,2", "iPhone9,3", "iPhone9,4": return "A10 Fusion"
        case "iPod9,1": return "A10 Fusion"
        case "iPad7,5", "iPad7,6", "iPad7,11", "iPad7,12": return "A10 Fusion"
        case "iPad7,3", "iPad7,4": return "A10X Fusion"

        // A10X (iPad Pro 10.5", iPad Pro 12.9" 2nd gen)
        case "iPad7,1", "iPad7,2": return "A10X Fusion"

        // A11 Bionic (iPhone 8 series, iPhone X)
        case "iPhone10,1", "iPhone10,2", "iPhone10,3", "iPhone10,4", "iPhone10,5", "iPhone10,6": return "A11 Bionic"

        // A12 Bionic (iPhone XS series, iPhone XR, iPad Air 3rd gen, iPad mini 5th gen, iPad 8th gen)
        case "iPhone11,2", "iPhone11,4", "iPhone11,6", "iPhone11,8": return "A12 Bionic"
        case "iPad11,1", "iPad11,2", "iPad11,3", "iPad11,4", "iPad11,6", "iPad11,7": return "A12 Bionic"

        // A12X Bionic (iPad Pro 11" 1st gen, iPad Pro 12.9" 3rd gen)
        case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4", "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8": return "A12X Bionic"

        // A12Z Bionic (iPad Pro 11" 2nd gen, iPad Pro 12.9" 4th gen)
        case "iPad8,9", "iPad8,10", "iPad8,11", "iPad8,12": return "A12Z Bionic"

        // A13 Bionic (iPhone 11 series, iPhone SE 2nd gen)
        case "iPhone12,1", "iPhone12,3", "iPhone12,5", "iPhone12,8": return "A13 Bionic"

        // A14 Bionic (iPhone 12 series, iPad Air 4th gen, iPad 9th gen)
        case "iPhone13,1", "iPhone13,2", "iPhone13,3", "iPhone13,4": return "A14 Bionic"
        case "iPad13,1", "iPad13,2", "iPad12,1", "iPad12,2": return "A14 Bionic"

        // A15 Bionic (iPhone 13 series, iPhone 14 series, iPhone SE 3rd gen, iPad mini 6th gen)
        case "iPhone14,2", "iPhone14,3", "iPhone14,6", "iPhone14,7", "iPhone14,8", "iPhone15,4", "iPhone15,5": return "A15 Bionic"
        case "iPad14,1", "iPad14,2": return "A15 Bionic"

        // A16 Bionic (iPhone 14 Pro series, iPhone 15 series)
        case "iPhone15,2", "iPhone15,3", "iPhone16,1", "iPhone16,2": return "A16 Bionic"

        // A17 Pro (iPhone 15 Pro series)
        case "iPhone16,3", "iPhone16,4": return "A17 Pro"

        // A18 (iPhone 16 series)
        case "iPhone17,1", "iPhone17,2": return "A18"
        case "iPhone17,3", "iPhone17,4": return "A18 Pro"

        // M1 (iPad Pro 11" 3rd gen, iPad Pro 12.9" 5th gen, iPad Air 5th gen)
        case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7", "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": return "M1"
        case "iPad14,3", "iPad14,4": return "M1"

        // M2 (iPad Pro 11" 4th gen, iPad Pro 12.9" 6th gen, iPad Air 6th gen)
        case "iPad14,5", "iPad14,6", "iPad14,10", "iPad14,11": return "M2"
        case "iPad14,8", "iPad14,9": return "M2"

        // Apple TV
        case "AppleTV5,3": return "A8"
        case "AppleTV6,2": return "A10X Fusion"
        case "AppleTV11,1": return "A12 Bionic"
        case "AppleTV14,1": return "A15 Bionic"

        // Mac (for Mac Catalyst)
        case let identifier where identifier.hasPrefix("Mac"): return "Apple Silicon"

        // Simulator
        case "x86_64": return "Intel x86_64"
        case "arm64": return "Apple Silicon (Simulator)"

        default: return "Unknown CPU"
        }
    }

    /// Get GPU model information
    private static func gpuModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        // Map device identifiers to GPU models
        switch identifier {
        // A9 GPU (iPhone 6s series, iPhone SE 1st gen)
        case "iPhone8,1", "iPhone8,2", "iPhone8,4": return "PowerVR GT7600 (A9)"
        case "iPad6,3", "iPad6,4": return "PowerVR 7XT (A9X)"
        case "iPad6,7", "iPad6,8": return "PowerVR 7XT (A9X)"

        // A10 GPU (iPhone 7 series, iPod touch 7th gen, iPad 6th/7th gen)
        case "iPhone9,1", "iPhone9,2", "iPhone9,3", "iPhone9,4": return "PowerVR GT7600 Plus (A10 Fusion)"
        case "iPod9,1": return "PowerVR GT7600 Plus (A10 Fusion)"
        case "iPad7,5", "iPad7,6", "iPad7,11", "iPad7,12": return "PowerVR GT7600 Plus (A10 Fusion)"
        case "iPad7,1", "iPad7,2", "iPad7,3", "iPad7,4": return "PowerVR 7XT Plus (A10X Fusion)"

        // A11 Bionic GPU (iPhone 8 series, iPhone X)
        case "iPhone10,1", "iPhone10,2", "iPhone10,3", "iPhone10,4", "iPhone10,5", "iPhone10,6": return "3-core GPU (A11 Bionic)"

        // A12 Bionic GPU (iPhone XS series, iPhone XR, iPad Air 3rd gen, iPad mini 5th gen, iPad 8th gen)
        case "iPhone11,2", "iPhone11,4", "iPhone11,6": return "4-core GPU (A12 Bionic)"
        case "iPhone11,8": return "3-core GPU (A12 Bionic)"
        case "iPad11,1", "iPad11,2", "iPad11,3", "iPad11,4", "iPad11,6", "iPad11,7": return "4-core GPU (A12 Bionic)"

        // A12X/A12Z Bionic GPU (iPad Pro models)
        case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4", "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8": return "7-core GPU (A12X Bionic)"
        case "iPad8,9", "iPad8,10", "iPad8,11", "iPad8,12": return "8-core GPU (A12Z Bionic)"

        // A13 Bionic GPU (iPhone 11 series, iPhone SE 2nd gen)
        case "iPhone12,1", "iPhone12,8": return "4-core GPU (A13 Bionic)"
        case "iPhone12,3", "iPhone12,5": return "4-core GPU (A13 Bionic)"

        // A14 Bionic GPU (iPhone 12 series, iPad Air 4th gen, iPad 9th gen)
        case "iPhone13,1", "iPhone13,2", "iPhone13,3", "iPhone13,4": return "4-core GPU (A14 Bionic)"
        case "iPad13,1", "iPad13,2", "iPad12,1", "iPad12,2": return "4-core GPU (A14 Bionic)"

        // A15 Bionic GPU (iPhone 13 series, iPhone 14 series, iPhone SE 3rd gen, iPad mini 6th gen)
        case "iPhone14,2", "iPhone14,3": return "5-core GPU (A15 Bionic)"
        case "iPhone14,6", "iPhone14,7", "iPhone14,8", "iPhone15,4", "iPhone15,5": return "4-core GPU (A15 Bionic)"
        case "iPad14,1", "iPad14,2": return "5-core GPU (A15 Bionic)"

        // A16 Bionic GPU (iPhone 14 Pro series, iPhone 15 series)
        case "iPhone15,2", "iPhone15,3": return "5-core GPU (A16 Bionic)"
        case "iPhone16,1", "iPhone16,2": return "5-core GPU (A16 Bionic)"

        // A17 Pro GPU (iPhone 15 Pro series)
        case "iPhone16,3", "iPhone16,4": return "6-core GPU (A17 Pro)"

        // A18 GPU (iPhone 16 series)
        case "iPhone17,1", "iPhone17,2": return "5-core GPU (A18)"
        case "iPhone17,3", "iPhone17,4": return "6-core GPU (A18 Pro)"

        // M1 GPU (iPad Pro 11" 3rd gen, iPad Pro 12.9" 5th gen, iPad Air 5th gen)
        case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7": return "8-core GPU (M1)"
        case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": return "8-core GPU (M1)"
        case "iPad14,3", "iPad14,4": return "8-core GPU (M1)"

        // M2 GPU (iPad Pro 11" 4th gen, iPad Pro 12.9" 6th gen, iPad Air 6th gen)
        case "iPad14,5", "iPad14,6": return "10-core GPU (M2)"
        case "iPad14,10", "iPad14,11": return "10-core GPU (M2)"
        case "iPad14,8", "iPad14,9": return "10-core GPU (M2)"

        // Apple TV
        case "AppleTV5,3": return "PowerVR GX6450 (A8)"
        case "AppleTV6,2": return "PowerVR 7XT Plus (A10X Fusion)"
        case "AppleTV11,1": return "4-core GPU (A12 Bionic)"
        case "AppleTV14,1": return "5-core GPU (A15 Bionic)"

        // Mac (for Mac Catalyst)
        case let identifier where identifier.hasPrefix("Mac"): return "Apple GPU"

        // Simulator
        case "x86_64": return "Intel Integrated Graphics"
        case "arm64": return "Apple GPU (Simulator)"

        default: return "Unknown GPU"
        }
    }

    /// Get OS version
    private static func osVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        #if os(iOS)
        #if targetEnvironment(macCatalyst)
        return "macOS \(versionString)"
        #else
        return "iOS \(versionString)"
        #endif
        #elseif os(tvOS)
        return "tvOS \(versionString)"
        #elseif os(macOS)
        return "macOS \(versionString)"
        #else
        return "Unknown OS \(versionString)"
        #endif
    }

    /// Get CPU core count
    private static func cpuCoreCount() -> Int {
        return ProcessInfo.processInfo.processorCount
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

    /// Format bytes to human-readable format
    public func formatBytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0

        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else {
            return String(format: "%.0f KB", kb)
        }
    }

    /// Format playtime in seconds to a human-readable format with appropriate detail level
    /// based on the duration
    public func formatPlaytime(_ seconds: Int) -> String {
        if seconds == 0 {
            return "No playtime recorded"
        }

        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60

        // Format based on the duration to show appropriate level of detail
        if days > 0 {
            if days > 365 {
                let years = days / 365
                let remainingDays = days % 365
                if remainingDays > 0 {
                    return String(format: "%dy %dd", years, remainingDays)
                } else {
                    return String(format: "%d years", years)
                }
            } else if days > 30 {
                let months = days / 30
                let remainingDays = days % 30
                if remainingDays > 0 {
                    return String(format: "%dm %dd", months, remainingDays)
                } else {
                    return String(format: "%d months", months)
                }
            } else {
                if hours > 0 {
                    return String(format: "%dd %dh", days, hours)
                } else {
                    return String(format: "%d days", days)
                }
            }
        } else if hours > 0 {
            if minutes > 0 {
                return String(format: "%dh %02dm", hours, minutes)
            } else {
                return String(format: "%d hours", hours)
            }
        } else {
            return String(format: "%d minutes", minutes)
        }
    }
}
