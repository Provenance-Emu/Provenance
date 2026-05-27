/// Shared diagnostic state for tracing the touch-to-core input pipeline
/// after app background/resume cycles. Filter Console.app with `[INPUT-DIAG]`.
///
/// Each flag is re-armed (set to `false`) in `appWillResignActive` and latched
/// `true` the first time that layer fires after resume, producing exactly one
/// log line per background/resume cycle at each layer of the pipeline.
///
/// Separate flags per layer let you detect mid-pipeline breakage: e.g.
/// MultiTouchView fires but DeltaSkinInputHandler doesn't means the touch
/// reached UIKit but died before the SwiftUI skin handler forwarded it.
public enum InputDiagnostics {
    /// OSD JSButton touch layer
    public static var hasLoggedJSButton: Bool = false
    /// OSD JSDPad touch layer
    public static var hasLoggedJSDPad: Bool = false
    /// DeltaSkin MultiTouchView (UIKit backing view for SwiftUI skin)
    public static var hasLoggedMultiTouch: Bool = false
    /// DeltaSkinInputHandler.buttonPressed (SwiftUI skin -> core bridge)
    public static var hasLoggedDeltaSkinPress: Bool = false

    /// Re-arm all flags. Called from `appWillResignActive`.
    public static func resetAll() {
        hasLoggedJSButton = false
        hasLoggedJSDPad = false
        hasLoggedMultiTouch = false
        hasLoggedDeltaSkinPress = false
    }
}
