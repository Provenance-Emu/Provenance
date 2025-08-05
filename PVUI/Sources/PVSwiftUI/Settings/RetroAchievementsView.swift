import SwiftUI
import PVUIBase
import PVCheevos
import Combine

/// RetroAchievements login and profile view with RetroWave styling
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
public struct RetroAchievementsView: View {
    // MARK: - State Management

    @State private var authMethod: AuthMethod = .apiKey
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var apiKey: String = ""
    @State private var isLoading = false
    @State private var loadingProgress: Double = 0
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var currentSession: RAUserSession?
    @State private var userProfile: RAUserProfile?

    // Animation properties
    @State private var glowIntensity: CGFloat = 0.5
    @State private var formScale: CGFloat = 1.0

    @Environment(\.dismiss) private var dismiss

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
                    if let profile = userProfile {
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
        .onAppear {
            startGlowAnimation()
            checkExistingAuth()
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

            Text(userProfile != nil ? "Welcome back, \(userProfile?.user ?? "User")!" : "Connect your account")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var loginFormView: some View {
        VStack(spacing: 20) {
            // Authentication method selector
            authMethodSelector

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
                ForEach(AuthMethod.allCases, id: \.self) { method in
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

            // Conditional fields based on auth method
            switch authMethod {
            case .apiKey:
                retroTextField(
                    title: "WEB API KEY",
                    text: $apiKey,
                    placeholder: "Enter your web API key",
                    icon: "key.fill",
                    isSecure: true
                )

            case .password:
                retroTextField(
                    title: "PASSWORD",
                    text: $password,
                    placeholder: "Enter your password",
                    icon: "lock.fill",
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

                Text(isLoading ? "CONNECTING..." : "CONNECT")
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
                Text("PROFILE")
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

            // Stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                profileStatCard(
                    title: "TOTAL POINTS",
                    value: "\(profile.totalPoints ?? 0)",
                    icon: "star.fill"
                )

                profileStatCard(
                    title: "TRUE POINTS",
                    value: "\(profile.totalTruePoints ?? 0)",
                    icon: "diamond.fill"
                )

                profileStatCard(
                    title: "MEMBER SINCE",
                    value: formatMemberSince(profile.memberSince),
                    icon: "calendar.badge.clock"
                )

                profileStatCard(
                    title: "CONTRIBUTIONS",
                    value: "\(profile.contribCount ?? 0)",
                    icon: "hammer.fill"
                )
            }

            // Logout button
            Button {
                performLogout()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16))

                    Text("DISCONNECT")
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
        !username.isEmpty && (
            (authMethod == .apiKey && !apiKey.isEmpty) ||
            (authMethod == .password && !password.isEmpty)
        )
    }

    // MARK: - Methods

    private func startGlowAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
    }

    private func clearForm() {
        username = ""
        password = ""
        apiKey = ""
    }

    private func checkExistingAuth() {
        // TODO: Check for stored credentials/session
        // This would be implemented with proper keychain storage
    }

    private func performLogin() {
        guard isFormValid else { return }

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
                let client: RetroAchievementsClient

                switch authMethod {
                case .apiKey:
                    client = PVCheevos.client(username: username, webAPIKey: apiKey)

                    // Validate credentials and get profile
                    let isValid = await client.validateCredentials()
                    if !isValid {
                        throw LoginError.invalidCredentials
                    }

                    let profile = try await client.getUserProfile(username: username)

                    await MainActor.run {
                        self.userProfile = profile
                        self.currentSession = nil
                        loadingProgress = 1.0

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.isLoading = false
                            self.formScale = 1.0
                        }
                    }

                case .password:
                    client = PVCheevos.clientWithPassword(username: username, password: password)

                    // Perform login to get session
                    let session = try await client.login(username: username, password: password)

                    await MainActor.run {
                        self.currentSession = session
                        self.userProfile = session.user
                        loadingProgress = 1.0

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.isLoading = false
                            self.formScale = 1.0
                        }
                    }
                }

                // TODO: Store credentials securely in keychain

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
        withAnimation(.easeOut(duration: 0.3)) {
            userProfile = nil
            currentSession = nil
            clearForm()
        }

        // TODO: Clear stored credentials from keychain
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
}

// MARK: - Supporting Types

enum LoginError: LocalizedError {
    case invalidCredentials
    case networkError
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid username or credentials. Please check your information."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .unknownError:
            return "An unknown error occurred. Please try again."
        }
    }
}

#if !os(tvOS)
/// Share sheet for tvOS compatibility
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
