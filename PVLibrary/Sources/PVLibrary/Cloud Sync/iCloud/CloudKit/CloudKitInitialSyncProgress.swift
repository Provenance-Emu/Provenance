//
//  CloudKitInitialSyncProgress.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

public struct CloudKitInitialSyncProgress {
    /// Total number of ROMs to sync
    public var romsTotal: Int = 0

    /// Number of ROMs synced
    public var romsCompleted: Int = 0

    /// Total number of save states to sync
    public var saveStatesTotal: Int = 0

    /// Number of save states synced
    public var saveStatesCompleted: Int = 0

    /// Total number of BIOS files to sync
    public var biosTotal: Int = 0

    /// Number of BIOS files synced
    public var biosCompleted: Int = 0

    /// Total number of battery states to sync
    public var batteryStatesTotal: Int = 0

    /// Number of battery states synced
    public var batteryStatesCompleted: Int = 0

    /// Total number of screenshots to sync
    public var screenshotsTotal: Int = 0

    /// Number of screenshots synced
    public var screenshotsCompleted: Int = 0

    /// Total number of Delta skins to sync
    public var deltaSkinsTotal: Int = 0

    /// Number of Delta skins synced
    public var deltaSkinsCompleted: Int = 0

    /// Whether the sync is complete
    public var isComplete: Bool = false

    /// Overall progress (0.0 - 1.0)
    public var overallProgress: Double {
        let total = Double(romsTotal + saveStatesTotal + biosTotal + batteryStatesTotal + screenshotsTotal + deltaSkinsTotal)
        let completed = Double(romsCompleted + saveStatesCompleted + biosCompleted + batteryStatesCompleted + screenshotsCompleted + deltaSkinsCompleted)

        guard total > 0 else { return 0 }
        return completed / total
    }
}
