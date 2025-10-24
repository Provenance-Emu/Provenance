import SwiftUI
import PVUIBase
import PVCheevos
import Combine

/// RetroAchievements login and profile view with RetroWave styling
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
public struct RetroAchievementsView: View {
    // MARK: - Configuration

    /// Controls which authentication methods are available
    private let enableAPIKeyAuth = false  // Set to true to enable API key authentication
    private let enablePasswordAuth = true // Set to false to disable password authentication

    // MARK: - State Management

    @State private var authMethod: AuthMethod = .password
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var apiKey: String = ""
    @State private var isLoading = false
    @State private var loadingProgress: Double = 0
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var userProfile: RAUserProfile?
    @State private var isAuthenticated = false

    // RetroArch configuration state
    @State private var retroAchievementsEnabled = false
    @State private var hardcoreModeEnabled = false

    // Animation properties
    @State private var glowIntensity: CGFloat = 0.5
    @State private var formScale: CGFloat = 1.0

    @Environment(\.dismiss) private var dismiss

    // RetroAchievements client
    @State private var client: RetroAchievementsClient?

    // Authentication method enum
    enum AuthMethod: String, CaseIterable {
        case apiKey = "API Key"
        case password = "Username & Password"

        var icon: String {
            switch self {
            case .apiKey: return "key.fill"
            case .password: return "person.badge.key.fill"
            }
        }

        var description: String {
            switch self {
            case .apiKey: return "Use your web API key for data access"
            case .password: return "Use username/password for real-time gaming"
            }
        }
    }

    // Computed property for available auth methods based on configuration
    private var availableAuthMethods: [AuthMethod] {
        var methods: [AuthMethod] = []
        if enablePasswordAuth { methods.append(.password) }
        if enableAPIKeyAuth { methods.append(.apiKey) }
        return methods
    }

    // Whether to show the auth method selector
    private var shouldShowAuthMethodSelector: Bool {
        return availableAuthMethods.count > 1
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // RetroWave background
            RetroTheme.retroBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView

                    // Main content based on authentication state
                    if isAuthenticated, let profile = userProfile {
                        // Show profile when authenticated
                        profileView(profile: profile)
                    } else if isLoading {
                        // Show loading state
                        loadingView
                    } else {
                        // Show login form
                        loginFormView
                    }
                }
                .padding()
            }
        }
        .navigationTitle("RetroAchievements")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await initializeClient()
        }
        .onAppear {
            startGlowAnimation()
            // Set default auth method to first available method
            if let firstMethod = availableAuthMethods.first {
                authMethod = firstMethod
            }
        }
        .retroAlert("Error",
                    message: errorMessage ?? "",
                    isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        }
    }

    // MARK: - UI Components

    private var headerView: some View {
        VStack(spacing: 12) {
            // Trophy icon with glow effect
            ZStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
                    .shadow(color: RetroTheme.retroPink.opacity(glowIntensity), radius: 10)
                    .shadow(color: RetroTheme.retroBlue.opacity(glowIntensity * 0.7), radius: 15)
            }

            Text("RETROACHIEVEMENTS")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .tracking(2)
                .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 2)

            Text(isAuthenticated ? "Welcome back, \(userProfile?.user ?? "User")!" : "Connect with your account")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var loginFormView: some View {
        VStack(spacing: 20) {
            // Info text
            VStack(spacing: 8) {
                Text("SIGN IN TO YOUR ACCOUNT")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
                    .tracking(1)

                Text(getAuthDescription())
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Authentication method selector (only show if multiple methods available)
            if shouldShowAuthMethodSelector {
                authMethodSelector
            }

            // Login form
            loginForm
                .scaleEffect(formScale)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: formScale)

            // Login button
            loginButton
        }
        .padding()
        .background(retroCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var authMethodSelector: some View {
        VStack(spacing: 12) {
            Text("AUTHENTICATION METHOD")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .tracking(1)

            HStack(spacing: 0) {
                ForEach(availableAuthMethods, id: \.self) { method in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            authMethod = method
                            clearForm()
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: method.icon)
                                .font(.system(size: 16, weight: .bold))

                            Text(method.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(0.5)
                        }
                        .foregroundColor(authMethod == method ? .white : .white.opacity(0.6))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(authMethod == method ?
                                    Color.black.opacity(0.6) :
                                    Color.black.opacity(0.3))
                    }
                }
            }
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(RetroTheme.retroGradient, lineWidth: 1)
            )

            Text(authMethod.description)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    private var loginForm: some View {
        VStack(spacing: 16) {
            // Username field (always shown)
            retroTextField(
                title: "USERNAME",
                text: $username,
                placeholder: "Enter your RetroAchievements username",
                icon: "person.fill"
            )

            // Conditional fields based on auth method and configuration
            if authMethod == .password && enablePasswordAuth {
                retroTextField(
                    title: "PASSWORD",
                    text: $password,
                    placeholder: "Enter your password",
                    icon: "lock.fill",
                    isSecure: true
                )
            }

            if authMethod == .apiKey && enableAPIKeyAuth {
                retroTextField(
                    title: "WEB API KEY",
                    text: $apiKey,
                    placeholder: "Enter your web API key",
                    icon: "key.fill",
                    isSecure: true
                )
            }
        }
    }

    private func retroTextField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String,
        isSecure: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
                    .font(.system(size: 12))

                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
                    .tracking(1)
            }

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            #if !os(tvOS)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            #endif
        }
    }

    private var loginButton: some View {
        Button {
            performLogin()
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                }

                Text(isLoading ? "CONNECTING..." : "SIGN IN")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(1)
            }
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(RetroTheme.retroGradient, lineWidth: 2)
                    )
            )
            .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 5)
        }
        .disabled(isLoading || !isFormValid)
        .opacity(isFormValid ? 1.0 : 0.6)
    }

    private var loadingView: some View {
        VStack(spacing: 24) {
            // Loading progress circle
            ZStack {
                Circle()
                    .stroke(RetroTheme.retroHorizontalGradient, lineWidth: 4)
                    .frame(width: 80, height: 80)
                    .blur(radius: 2 * glowIntensity)

                Circle()
                    .trim(from: 0, to: loadingProgress)
                    .stroke(
                        RetroTheme.retroHorizontalGradient,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 4)

                Text("\(Int(loadingProgress * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
            }

            Text("AUTHENTICATING")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .tracking(2)
        }
        .padding()
        .background(retroCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func profileView(profile: RAUserProfile) -> some View {
        VStack(spacing: 20) {
            // Profile header
            VStack(spacing: 12) {
                Text("CONNECTED")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
                    .tracking(2)

                // User avatar placeholder
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .strokeBorder(RetroTheme.retroGradient, lineWidth: 2)
                        )

                    Image(systemName: "person.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)
                }
                .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 5)

                Text(profile.user.uppercased())
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1)
            }

            // Stats grid - only show relevant stats based on auth method
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {

                // Always show basic stats
                profileStatCard(
                    title: "MEMBER SINCE",
                    value: formatMemberSince(profile.memberSince),
                    icon: "calendar.badge.clock"
                )

                // Show points only if available (mainly for API key auth)
                if let totalPoints = profile.totalPoints, totalPoints > 0 {
                    profileStatCard(
                        title: "TOTAL POINTS",
                        value: "\(totalPoints)",
                        icon: "star.fill"
                    )
                }

                if let truePoints = profile.totalTruePoints, truePoints > 0 {
                    profileStatCard(
                        title: "TRUE POINTS",
                        value: "\(truePoints)",
                        icon: "diamond.fill"
                    )
                }

                if let contributions = profile.contribCount, contributions > 0 {
                    profileStatCard(
                        title: "CONTRIBUTIONS",
                        value: "\(contributions)",
                        icon: "hammer.fill"
                    )
                }
            }

            // RetroArch Configuration Section
            retroArchConfigSection

            // Logout button
            Button {
                performLogout()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16))

                    Text("SIGN OUT")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .tracking(1)
                }
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.red.opacity(0.6), lineWidth: 1)
                        )
                )
            }
        }
        .padding()
        .background(retroCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var retroArchConfigSection: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
                    .font(.system(size: 16))

                Text("RETROARCH INTEGRATION")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
                    .tracking(1)

                Spacer()
            }

            VStack(spacing: 12) {
                // Enable RetroAchievements toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable RetroAchievements")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)

                        Text("Sync achievements with RetroArch cores")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    Toggle("", isOn: $retroAchievementsEnabled)
                        .toggleStyle(RetroToggleStyle())
                        .onChange(of: retroAchievementsEnabled) { newValue in
                            PVCheevos.retroArch.isRetroAchievementsEnabled = newValue
                        }
                }

                // Hardcore mode toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hardcore Mode")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)

                        Text("Disables savestates and cheating features. Achievements earned in hardcore mode are uniquely marked.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Toggle("", isOn: $hardcoreModeEnabled)
                        .toggleStyle(RetroToggleStyle())
                        .onChange(of: hardcoreModeEnabled) { newValue in
                            PVCheevos.retroArch.isHardcoreModeEnabled = newValue
                        }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func profileStatCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .tracking(0.5)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var retroCardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.black.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                RetroTheme.retroPink.opacity(0.3),
                                RetroTheme.retroBlue.opacity(0.3),
                                RetroTheme.retroPurple.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        guard !username.isEmpty else { return false }

        switch authMethod {
        case .apiKey:
            return enableAPIKeyAuth && !apiKey.isEmpty
        case .password:
            return enablePasswordAuth && !password.isEmpty
        }
    }

    // MARK: - Methods

    private func startGlowAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
    }

    private func initializeClient() async {
        // Create client and check for existing session
        client = PVCheevos.client()

        await MainActor.run {
            // Check if already authenticated
            if let currentClient = client {
                Task {
                    let authenticated = await currentClient.isAuthenticated
                    let currentUser = await currentClient.currentUsername

                    await MainActor.run {
                        isAuthenticated = authenticated
                        if authenticated {
                            // Load stored profile or create basic one
                            if let storedProfile = RetroCredentialsManager.shared.loadUserProfile() {
                                userProfile = storedProfile
                            }
                        }

                        // Load RetroArch settings
                        loadRetroArchSettings()
                    }
                }
            }
        }
    }

    private func loadRetroArchSettings() {
        retroAchievementsEnabled = PVCheevos.retroArch.isRetroAchievementsEnabled
        hardcoreModeEnabled = PVCheevos.retroArch.isHardcoreModeEnabled
    }

    private func performLogin() {
        guard isFormValid, let client = client else { return }

        isLoading = true
        loadingProgress = 0.1

        withAnimation(.easeInOut(duration: 0.3)) {
            formScale = 0.95
        }

        Task {
            // Simulate loading progress
            for progress in stride(from: 0.1, to: 0.9, by: 0.1) {
                try? await Task.sleep(nanoseconds: 200_000_000)
                await MainActor.run {
                    loadingProgress = progress
                }
            }

            do {
                switch authMethod {
                case .apiKey:
                    // Use legacy API key client for data access
                    let apiClient = PVCheevos.client(username: username, webAPIKey: apiKey)

                    // Validate credentials and get profile
                    let isValid = await apiClient.validateCredentials()
                    if !isValid {
                        throw LoginError.invalidCredentials
                    }

                    let profile = try await apiClient.getUserProfile(username: username)

                    await MainActor.run {
                        self.userProfile = profile
                        self.isAuthenticated = true
                        loadingProgress = 1.0

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.isLoading = false
                            self.formScale = 1.0
                            // Clear form
                            self.username = ""
                            self.apiKey = ""
                        }
                    }

                case .password:
                    // Use username/password authentication with storage
                    let session = try await client.login(username: username, password: password)

                    await MainActor.run {
                        self.userProfile = session.user
                        self.isAuthenticated = true
                        loadingProgress = 1.0

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.isLoading = false
                            self.formScale = 1.0
                            // Clear form
                            self.username = ""
                            self.password = ""
                        }
                    }
                }

            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isLoading = false
                    self.formScale = 1.0
                    loadingProgress = 0
                }
            }
        }
    }

    private func performLogout() {
        guard let client = client else { return }

        Task {
            await client.logout()

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    userProfile = nil
                    isAuthenticated = false
                    username = ""
                    password = ""
                    apiKey = ""
                }
            }
        }
    }

    private func formatMemberSince(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "Unknown" }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM yyyy"
            return displayFormatter.string(from: date)
        }

        return dateString
    }

    private func getAuthDescription() -> String {
        if shouldShowAuthMethodSelector {
            switch authMethod {
            case .apiKey:
                return "Enter your web API key to access achievement data and statistics."
            case .password:
                return "Enter your username and password to track achievements and compete with friends."
            }
        } else {
            // Single method available
            if enablePasswordAuth {
                return "Enter your RetroAchievements username and password to track achievements and compete with friends."
            } else if enableAPIKeyAuth {
                return "Enter your web API key to access achievement data and statistics."
            } else {
                return "No authentication methods available."
            }
        }
    }

    private func clearForm() {
        username = ""
        password = ""
        apiKey = ""
    }
}

// MARK: - Custom Toggle Style

struct RetroToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            Spacer()

            Button {
                configuration.isOn.toggle()
            } label: {
                RoundedRectangle(cornerRadius: 16)
                    .fill(configuration.isOn ? RetroTheme.retroHorizontalGradient : Color.black.opacity(0.6))
                    .frame(width: 50, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                configuration.isOn ?
                                    Color.clear :
                                    Color.white.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 26, height: 26)
                            .offset(x: configuration.isOn ? 10 : -10)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Supporting Types

enum LoginError: LocalizedError {
    case invalidCredentials
    case networkError
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password. Please check your information."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .unknownError:
            return "An unknown error occurred. Please try again."
        }
    }
}
