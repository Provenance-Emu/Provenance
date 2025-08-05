@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
private struct RetroAchievementsSection: View {
    @ObservedObject var viewModel: PVSettingsViewModel
    @State private var isAuthenticated = false
    @State private var currentUsername: String?

    var body: some View {
        Section(header: Text("RetroAchievements")) {
            NavigationLink(destination: RetroAchievementsView()) {
                SettingsRow(
                    title: "RetroAchievements",
                    subtitle: isAuthenticated ?
                              "Signed in as \(currentUsername ?? "User")" :
                              "Sign in to track achievements and compete with friends",
                    value: isAuthenticated ? "Connected" : nil,
                    icon: .sfSymbol("trophy.fill")
                )
            }
        }
        .onAppear {
            checkAuthenticationStatus()
        }
    }

    private func checkAuthenticationStatus() {
        // Check if user has stored credentials or active session
        isAuthenticated = PVCheevos.hasValidSession

        if isAuthenticated {
            // Try to get stored username
            if let profile = RetroCredentialsManager.shared.loadUserProfile() {
                currentUsername = profile.user
            } else if let credentials = RetroCredentialsManager.shared.loadCredentials() {
                currentUsername = credentials.username
            }
        }
    }
}
