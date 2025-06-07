import UIKit
import PVEmulatorCore
import PVLibrary
import PVLogging

// MARK: - Screen Filter Extension

/// Extension to add screen filter support to the emulator view controller
extension PVEmulatorViewController {
    
    /// Apply a screen filter to the game display
    /// - Parameter filter: The filter to apply, or nil to remove any existing filter
    public func applyScreenFilter(_ filter: DeltaSkinScreenFilter?) {
        // Store the filter for later reference
        self.currentScreenFilter = filter
        
        // Apply the filter to the Metal view
        if let metalVC = gpuViewController as? PVMetalViewController {
            if let filter = filter {
                ILOG("Applying screen filter: \(filter.filter.name)")
                metalVC.applyFilter(filter)
            } else {
                ILOG("Removing screen filter")
                metalVC.removeFilter()
            }
            
            // Force a redraw to show the filter immediately
            metalVC.draw(in: metalVC.mtlView)
        } else {
            ELOG("Cannot apply filter - no Metal view controller found")
        }
    }
    
    /// Get the current screen filter
    /// - Returns: The current screen filter, or nil if none is applied
    public func currentFilter() -> DeltaSkinScreenFilter? {
        return currentScreenFilter
    }
    
    /// Property to store the current screen filter
    private struct AssociatedKeys {
        static var currentScreenFilterKey = "PVEmulatorViewController.currentScreenFilter"
    }
    
    /// The current screen filter
    private var currentScreenFilter: DeltaSkinScreenFilter? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.currentScreenFilterKey) as? DeltaSkinScreenFilter
        }
        set {
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.currentScreenFilterKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

// MARK: - Metal View Controller Extension for Filters

/// Extension to add filter support to the Metal view controller
extension PVMetalViewController {
    
    /// Apply a filter to the Metal view
    /// - Parameter filter: The filter to apply
    func applyFilter(_ filter: DeltaSkinScreenFilter) {
        // Store the filter for use during rendering
        self.filter = filter
    }
    
    /// Remove any applied filter
    func removeFilter() {
        self.filter = nil
    }
    
    /// Property to store the current filter
    private struct AssociatedKeys {
        static var filterKey = "PVMetalViewController.filter"
    }
    
    /// The current filter
    var filter: DeltaSkinScreenFilter? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.filterKey) as? DeltaSkinScreenFilter
        }
        set {
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.filterKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    /// Apply the filter during rendering
    /// - Parameters:
    ///   - image: The CIImage to filter
    ///   - frame: The frame to apply the filter in
    /// - Returns: The filtered image, or the original if no filter is applied
    func applyFilter(to image: CIImage, in frame: CGRect) -> CIImage {
        guard let filter = self.filter else {
            return image
        }
        
        return filter.apply(to: image, in: frame) ?? image
    }
}
