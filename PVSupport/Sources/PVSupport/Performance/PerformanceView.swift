/// Performance view. Displays performance information above status bar. Appearance and output can be changed via properties.
internal class PerformanceView: UIWindow, PerformanceViewConfigurator {

    // MARK: Structs

    private struct Constants {
        static let preferredHeight: CGFloat = 20.0
        static let borderWidth: CGFloat = 1.0
        static let cornerRadius: CGFloat = 5.0
        static let pointSize: CGFloat = 8.0
        static let defaultStatusBarHeight: CGFloat = 20.0
        static let safeAreaInsetDifference: CGFloat = 11.0
    }

    // MARK: Public Properties

    /// Allows to change the format of the displayed information.
    public var options = PerformanceMonitor.DisplayOptions.default {
        didSet {
            self.configureStaticInformation()
        }
    }

    public var userInfo = PerformanceMonitor.UserInfo.none {
        didSet {
            self.configureUserInformation()
        }
    }

    /// Allows to change the appearance of the displayed information.
    public var style = PerformanceMonitor.Style.dark {
        didSet {
            self.configureView(withStyle: self.style)
        }
    }

    /// Allows to add gesture recognizers to the view.
    public var interactors: [UIGestureRecognizer]? {
        didSet {
            self.configureView(withInteractors: self.interactors)
        }
    }

    // MARK: Private Properties

    private let monitoringTextLabel = MarginLabel()
    private var staticInformation: String?
    private var userInformation: String?

    // MARK: Init Methods & Superclass Overriders

    required internal init() {
        super.init(frame: PerformanceView.windowFrame(withPreferredHeight: Constants.preferredHeight))
        self.windowScene = PerformanceView.keyWindowScene()

        self.configureWindow()
        self.configureMonitoringTextLabel()
        self.subscribeToNotifications()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.layoutWindow()
    }

    override func becomeKey() {
        self.isHidden = true

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            self.showViewAboveStatusBarIfNeeded()
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let interactors = self.interactors, interactors.count > 0 else {
            return false
        }
        return super.point(inside: point, with: event)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: Public Methods
internal extension PerformanceView {
    /// Hides monitoring view.
    func hide() {
        self.monitoringTextLabel.isHidden = true
    }

    /// Shows monitoring view.
    func show() {
        self.monitoringTextLabel.isHidden = false
    }

    /// Updates monitoring label with performance report.
    ///
    /// - Parameter report: Performance report.
    func update(withPerformanceReport report: PerformanceReport) {
        var monitoringTexts: [String] = []
        if self.options.contains(.performance) {
            let performance = String(format: "CPU: %.1f%%, FPS: %d", report.cpuUsage, report.fps)
            monitoringTexts.append(performance)
        }

        if self.options.contains(.memory) {
            let bytesInMegabyte = 1024.0 * 1024.0
            let usedMemory = Double(report.memoryUsage.used) / bytesInMegabyte
            let totalMemory = Double(report.memoryUsage.total) / bytesInMegabyte
            let memory = String(format: "%.1f of %.0f MB used", usedMemory, totalMemory)
            monitoringTexts.append(memory)
        }

        if let staticInformation = self.staticInformation {
            monitoringTexts.append(staticInformation)
        }

        if let userInformation = self.userInformation {
            monitoringTexts.append(userInformation)
        }

        self.monitoringTextLabel.text = (monitoringTexts.count > 0 ? monitoringTexts.joined(separator: "\n") : nil)
        self.showViewAboveStatusBarIfNeeded()
        self.layoutMonitoringLabel()
    }
}

// MARK: Notifications & Observers
private extension PerformanceView {
    func applicationWillChangeStatusBarFrame(notification: Notification) {
        self.layoutWindow()
    }
}

// MARK: Configurations
private extension PerformanceView {
    func configureWindow() {
        self.rootViewController = WindowViewController()
        self.windowLevel = UIWindow.Level.statusBar + 1.0
        self.backgroundColor = .clear
        self.clipsToBounds = true
        self.isHidden = true
    }

    func configureMonitoringTextLabel() {
        self.monitoringTextLabel.textAlignment = NSTextAlignment.center
        self.monitoringTextLabel.numberOfLines = 0
        self.monitoringTextLabel.clipsToBounds = true
        self.addSubview(self.monitoringTextLabel)
    }

    func configureStaticInformation() {
        var staticInformation: [String] = []
        if self.options.contains(.application) {
            let applicationVersion = self.applicationVersion()
            staticInformation.append(applicationVersion)
        }
        if self.options.contains(.device) {
            let deviceModel = self.deviceModel()
            staticInformation.append(deviceModel)
        }
        if self.options.contains(.system) {
            let systemVersion = self.systemVersion()
            staticInformation.append(systemVersion)
        }

        self.staticInformation = (staticInformation.count > 0 ? staticInformation.joined(separator: ", ") : nil)
    }

    func configureUserInformation() {
        var staticInformation: String?
        switch self.userInfo {
        case .none:
            break
        case .custom(let string):
            staticInformation = string
        }

        self.userInformation = staticInformation
    }

    func subscribeToNotifications() {
        NotificationCenter.default.addObserver(forName: UIApplication.willChangeStatusBarFrameNotification, object: nil, queue: .main) { [weak self] (notification) in
            self?.applicationWillChangeStatusBarFrame(notification: notification)
        }
    }

    func configureView(withStyle style: PerformanceMonitor.Style) {
        switch style {
        case .dark:
            self.monitoringTextLabel.backgroundColor = .black
            self.monitoringTextLabel.layer.borderColor = UIColor.white.cgColor
            self.monitoringTextLabel.layer.borderWidth = Constants.borderWidth
            self.monitoringTextLabel.layer.cornerRadius = Constants.cornerRadius
            self.monitoringTextLabel.textColor = .white
            self.monitoringTextLabel.font = UIFont.systemFont(ofSize: Constants.pointSize)
        case .light:
            self.monitoringTextLabel.backgroundColor = .white
            self.monitoringTextLabel.layer.borderColor = UIColor.black.cgColor
            self.monitoringTextLabel.layer.borderWidth = Constants.borderWidth
            self.monitoringTextLabel.layer.cornerRadius = Constants.cornerRadius
            self.monitoringTextLabel.textColor = .black
            self.monitoringTextLabel.font = UIFont.systemFont(ofSize: Constants.pointSize)
        case .custom(let backgroundColor, let borderColor, let borderWidth, let cornerRadius, let textColor, let font):
            self.monitoringTextLabel.backgroundColor = backgroundColor
            self.monitoringTextLabel.layer.borderColor = borderColor.cgColor
            self.monitoringTextLabel.layer.borderWidth = borderWidth
            self.monitoringTextLabel.layer.cornerRadius = cornerRadius
            self.monitoringTextLabel.textColor = textColor
            self.monitoringTextLabel.font = font
        }
    }

    func configureView(withInteractors interactors: [UIGestureRecognizer]?) {
        if let recognizers = self.gestureRecognizers {
            for recognizer in recognizers {
                self.removeGestureRecognizer(recognizer)
            }
        }

        if let recognizers = interactors {
            for recognizer in recognizers {
                self.addGestureRecognizer(recognizer)
            }
        }
    }
}

// MARK: Layout View
private extension PerformanceView {
    func layoutWindow() {
        self.frame = PerformanceView.windowFrame(withPreferredHeight: self.monitoringTextLabel.bounds.height)
        self.layoutMonitoringLabel()
    }

    func layoutMonitoringLabel() {
        let windowWidth = self.bounds.width
        let windowHeight = self.bounds.height
        let labelSize = self.monitoringTextLabel.sizeThatFits(CGSize(width: windowWidth, height: CGFloat.greatestFiniteMagnitude))

        if windowHeight != labelSize.height {
            self.frame = PerformanceView.windowFrame(withPreferredHeight: self.monitoringTextLabel.bounds.height)
        }

        self.monitoringTextLabel.frame = CGRect(x: (windowWidth - labelSize.width) / 2.0, y: (windowHeight - labelSize.height) / 2.0, width: labelSize.width, height: labelSize.height)
    }
}

// MARK: Support Methods
private extension PerformanceView {
    func showViewAboveStatusBarIfNeeded() {
        guard UIApplication.shared.applicationState == UIApplication.State.active, self.canBeVisible(), self.isHidden else {
            return
        }
        self.isHidden = false
    }

    func applicationVersion() -> String {
        var applicationVersion = "<null>"
        var applicationBuildNumber = "<null>"
        if let infoDictionary = Bundle.main.infoDictionary {
            if let versionNumber = infoDictionary["CFBundleShortVersionString"] as? String {
                applicationVersion = versionNumber
            }
            if let buildNumber = infoDictionary["CFBundleVersion"] as? String {
                applicationBuildNumber = buildNumber
            }
        }
        return "app v\(applicationVersion) (\(applicationBuildNumber))"
    }

    func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let model = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else {
                return identifier
            }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return model
    }

    func systemVersion() -> String {
        let systemName = UIDevice.current.systemName
        let systemVersion = UIDevice.current.systemVersion
        return "\(systemName) v\(systemVersion)"
    }

    func canBeVisible() -> Bool {
        if let window = PerformanceView.keyWindow(), window.isKeyWindow, !window.isHidden {
            return true
        }
        return false
    }
}

// MARK: Class Methods
private extension PerformanceView {
    class func windowFrame(withPreferredHeight height: CGFloat) -> CGRect {
        guard let window = PerformanceView.keyWindow() else {
            return .zero
        }

        var topInset: CGFloat = 0.0
        if let safeAreaTop = window.rootViewController?.view.safeAreaInsets.top {
            if safeAreaTop > 0.0 {
                if safeAreaTop > Constants.defaultStatusBarHeight {
                    topInset = safeAreaTop - Constants.safeAreaInsetDifference
                } else {
                    topInset = safeAreaTop - Constants.defaultStatusBarHeight
                }
            } else {
                topInset = safeAreaTop
            }
        }
        return CGRect(x: 0.0, y: topInset, width: window.bounds.width, height: height)
    }

    class func keyWindow() -> UIWindow? {
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
    }

    class func keyWindowScene() -> UIWindowScene? {
        return UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first as? UIWindowScene
    }
}
