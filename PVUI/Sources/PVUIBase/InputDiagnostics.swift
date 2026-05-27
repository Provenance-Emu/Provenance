/// Shared diagnostic state for tracing the touch-to-core input pipeline
/// after app background/resume cycles. Filter Console.app with `[INPUT-DIAG]`.
///
/// The flag is re-armed (set to `false`) in `appWillResignActive` and latched
/// `true` the first time a touch fires after resume, producing exactly one log
/// line per background/resume cycle at each layer of the pipeline.
public enum InputDiagnostics {
    /// Set to `false` in appWillResignActive, latched `true` on first touch post-resume.
    public static var hasLoggedFirstTouchSinceResume: Bool = false
}
