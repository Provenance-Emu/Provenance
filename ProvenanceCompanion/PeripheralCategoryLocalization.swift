import PVUSBManager

extension PeripheralCategory {
    /// Localized display name for use in UI section headers and labels.
    /// Falls back to `rawValue` (English) if no translation is found.
    var localizedName: String {
        String(localized: String.LocalizationValue(localizationKey))
    }
}
