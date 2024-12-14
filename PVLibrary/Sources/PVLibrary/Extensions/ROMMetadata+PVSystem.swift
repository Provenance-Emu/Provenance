import PVLookup
import PVLookupTypes

public extension ROMMetadata {
    /// The corresponding PVSystem for this ROM metadata
    var system: PVSystem? {
        return PVEmulatorConfiguration.system(forDatabaseID: systemID)
    }
}
