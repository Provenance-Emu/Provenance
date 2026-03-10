import Testing
import Foundation
@testable import PVCheevos

/// Thread-safe response queue for multi-request mock sequences
private actor ResponseQueue {
    private var queue: [(data: Data, statusCode: Int)] = []

    func enqueue(data: Data, statusCode: Int) {
        queue.append((data: data, statusCode: statusCode))
    }

    func dequeue() -> (data: Data, statusCode: Int)? {
        guard !queue.isEmpty else { return nil }
        return queue.removeFirst()
    }
}

/// Mock URLSession for testing network requests
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    var mockData: Data?
    var mockResponse: HTTPURLResponse?
    var mockError: Error?

    private let responseQueue = ResponseQueue()

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }

        if let next = await responseQueue.dequeue() {
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: next.statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (next.data, response)
        }

        let data = mockData ?? Data()
        let response = mockResponse ?? HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        return (data, response)
    }

    func setMockResponse(data: Data, statusCode: Int = 200) {
        self.mockData = data
        self.mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )
    }

    func setMockError(_ error: Error) {
        self.mockError = error
    }

    /// Enqueue ordered responses for multi-request flows
    func enqueueResponse(data: Data, statusCode: Int = 200) async {
        await responseQueue.enqueue(data: data, statusCode: statusCode)
    }
}

@Suite("RetroArchConfigManager", .serialized)
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
struct RetroArchConfigManagerTests {
    /// Canonical shared-app key used by gameplay and settings.
    private let enabledKey = "retroAchievementsEnabled"
    /// Canonical shared-app key used by gameplay and settings.
    private let hardcoreKey = "retroAchievementsHardcoreEnabled"
    /// Legacy RetroArch-only compatibility key.
    private let legacyEnabledKey = "ra_cheevos_enabled"
    /// Legacy RetroArch-only compatibility key.
    private let legacyHardcoreKey = "ra_cheevos_hardcore_mode"

    /// Removes RetroAchievements settings keys so tests can run independently.
    private func clearDefaults() {
        let defaults = UserDefaults.standard
        [enabledKey, hardcoreKey, legacyEnabledKey, legacyHardcoreKey].forEach(defaults.removeObject(forKey:))
    }

    @Test("Migrates the legacy enabled key into the canonical app key")
    func migratesLegacyEnabledKey() {
        clearDefaults()
        defer { clearDefaults() }

        UserDefaults.standard.set(true, forKey: legacyEnabledKey)

        #expect(RetroArchConfigManager.shared.isRetroAchievementsEnabled == true)
        #expect(UserDefaults.standard.object(forKey: enabledKey) != nil)
        #expect(UserDefaults.standard.bool(forKey: enabledKey) == true)
    }

    @Test("Canonical enabled key wins when both keys exist")
    func canonicalEnabledKeyWins() {
        clearDefaults()
        defer { clearDefaults() }

        UserDefaults.standard.set(false, forKey: enabledKey)
        UserDefaults.standard.set(true, forKey: legacyEnabledKey)

        #expect(RetroArchConfigManager.shared.isRetroAchievementsEnabled == false)
    }

    @Test("Writes hardcore mode to canonical and legacy keys")
    func writesHardcoreModeToBothKeys() {
        clearDefaults()
        defer { clearDefaults() }

        RetroArchConfigManager.shared.writeBooleanSetting(
            true,
            primaryKey: hardcoreKey,
            legacyKey: legacyHardcoreKey
        )

        #expect(UserDefaults.standard.bool(forKey: hardcoreKey) == true)
        #expect(UserDefaults.standard.bool(forKey: legacyHardcoreKey) == true)
    }
}

// MARK: - Credentials Tests
@Test func testCredentialsCreation() {
    let credentials = RetroCredentials.webAPIKey(username: "testuser", webAPIKey: "testkey")
    #expect(credentials.username == "testuser")

    let passwordCredentials = RetroCredentials.usernamePassword(username: "testuser", password: "testpass")
    #expect(passwordCredentials.username == "testuser")

    let authenticatedCredentials = RetroCredentials.token(username: "testuser", token: "testtoken")
    #expect(authenticatedCredentials.username == "testuser")
}

@Test func testPVCheevosCredentialsHelper() {
    let credentials = PVCheevos.credentials(username: "testuser", webAPIKey: "testkey")
    #expect(credentials.username == "testuser")

    let passwordCredentials = PVCheevos.credentialsWithPassword(username: "testuser", password: "testpass")
    #expect(passwordCredentials.username == "testuser")
}

@Test func testLegacyCredentialsCreation() {
    let credentials = RetroCredentials(username: "testuser", webAPIKey: "testkey")
    #expect(credentials.username == "testuser")
}

// MARK: - Client Creation Tests
@Test func testClientCreation() async {
    let client = PVCheevos.client(username: "testuser", webAPIKey: "testkey")
    let isAuth = await client.isAuthenticated
    #expect(isAuth == false)
}

// MARK: - Error Tests
@Test func testRetroErrorDescription() {
    #expect(RetroError.invalidCredentials.localizedDescription == "Invalid credentials provided")
    #expect(RetroError.unauthorized.localizedDescription == "Authentication failed")
    #expect(RetroError.notFound.localizedDescription == "Resource not found")
    #expect(RetroError.rateLimitExceeded.localizedDescription == "Rate limit exceeded")

    let customError = RetroError.custom("Custom error message")
    #expect(customError.localizedDescription == "Custom error message")

    let serverError = RetroError.serverError("Server issue")
    #expect(serverError.localizedDescription == "Server error: Server issue")
}

// MARK: - Network Client Tests
@Test func testNetworkClientSuccessfulRequest() async throws {
    let mockSession = MockURLSession()
    let testData = """
    {
        "User": "testuser",
        "TotalPoints": 1000
    }
    """.data(using: .utf8)!

    mockSession.setMockResponse(data: testData)

    let networkClient = RetroNetworkClient(urlSession: mockSession)
    let data = try await networkClient.performRequest(endpoint: "test", parameters: [:])

    #expect(data == testData)
}

@Test func testNetworkClient401Error() async {
    let mockSession = MockURLSession()
    mockSession.setMockResponse(data: Data(), statusCode: 401)

    let networkClient = RetroNetworkClient(urlSession: mockSession)

    do {
        _ = try await networkClient.performRequest(endpoint: "test")
        #expect(Bool(false), "Should have thrown an error")
    } catch let error as RetroError {
        if case .unauthorized = error {
            // Expected
        } else {
            #expect(Bool(false), "Expected unauthorized error")
        }
    } catch {
        #expect(Bool(false), "Expected RetroError")
    }
}

@Test func testNetworkClient404Error() async {
    let mockSession = MockURLSession()
    mockSession.setMockResponse(data: Data(), statusCode: 404)

    let networkClient = RetroNetworkClient(urlSession: mockSession)

    do {
        _ = try await networkClient.performRequest(endpoint: "test")
        #expect(Bool(false), "Should have thrown an error")
    } catch let error as RetroError {
        if case .notFound = error {
            // Expected
        } else {
            #expect(Bool(false), "Expected notFound error")
        }
    } catch {
        #expect(Bool(false), "Expected RetroError")
    }
}

@Test func testNetworkClientJSONDecoding() async throws {
    let mockSession = MockURLSession()
    let testData = """
    {
        "User": "testuser",
        "TotalPoints": 1000
    }
    """.data(using: .utf8)!

    mockSession.setMockResponse(data: testData)

    let networkClient = RetroNetworkClient(urlSession: mockSession)
    let response: UserProfile = try await networkClient.performRequest(
        endpoint: "test",
        responseType: UserProfile.self
    )

    #expect(response.user == "testuser")
    #expect(response.totalPoints == 1000)
}

// MARK: - API Client Tests
@Test func testGetUserProfileSuccess() async throws {
    let mockSession = MockURLSession()
    let testData = """
    {
        "User": "testuser",
        "TotalPoints": 1500,
        "MemberSince": "2020-01-01",
        "Motto": "Game on!"
    }
    """.data(using: .utf8)!

    mockSession.setMockResponse(data: testData)

    let credentials = RetroCredentials.webAPIKey(username: "testuser", webAPIKey: "testkey")
    let client = RetroAchievementsClient(credentials: credentials, urlSession: mockSession)

    let profile = try await client.getUserProfile(username: "testuser")

    #expect(profile.user == "testuser")
    #expect(profile.totalPoints == 1500)
    #expect(profile.memberSince == "2020-01-01")
    #expect(profile.motto == "Game on!")
}

@Test func testGetUserAwardsSuccess() async throws {
    let mockSession = MockURLSession()
    let testData = """
    {
        "TotalAwardsCount": 5,
        "MasteryAwardsCount": 2,
        "VisibleUserAwards": [
            {
                "AwardedAt": "2023-01-01",
                "AwardType": "Mastery",
                "Title": "Game Master"
            }
        ]
    }
    """.data(using: .utf8)!

    mockSession.setMockResponse(data: testData)

    let credentials = RetroCredentials.webAPIKey(username: "testuser", webAPIKey: "testkey")
    let client = RetroAchievementsClient(credentials: credentials, urlSession: mockSession)

    let awards = try await client.getUserAwards(username: "testuser")

    #expect(awards.totalAwardsCount == 5)
    #expect(awards.masteryAwardsCount == 2)
    #expect(awards.visibleUserAwards?.count == 1)
    #expect(awards.visibleUserAwards?.first?.title == "Game Master")
}

@Test func testCredentialValidation() async {
    let mockSession = MockURLSession()
    let testData = """
    {
        "User": "testuser",
        "TotalPoints": 1000
    }
    """.data(using: .utf8)!

    mockSession.setMockResponse(data: testData)

    let credentials = RetroCredentials.webAPIKey(username: "testuser", webAPIKey: "validkey")
    let client = RetroAchievementsClient(credentials: credentials, urlSession: mockSession)

    let isValid = await client.validateCredentials()
    #expect(isValid == true)
}

@Test func testCredentialValidationFailure() async {
    let mockSession = MockURLSession()
    mockSession.setMockResponse(data: Data(), statusCode: 401)

    let credentials = RetroCredentials.webAPIKey(username: "testuser", webAPIKey: "invalidkey")
    let client = RetroAchievementsClient(credentials: credentials, urlSession: mockSession)

    let isValid = await client.validateCredentials()
    #expect(isValid == false)
}

// MARK: - Login Tests

/// Verifies that login followed by full profile fetch populates all profile fields
@Test func testLoginPopulatesFullProfile() async throws {
    RetroCredentialsManager.shared.clearAll()
    let mockSession = MockURLSession()

    let loginData = """
    {
        "Success": true,
        "User": "testuser",
        "Token": "auth_token_12345",
        "Score": 1500,
        "SoftcoreScore": 800,
        "Permissions": 1,
        "AccountType": "Registered"
    }
    """.data(using: .utf8)!

    let fullProfileData = """
    {
        "User": "testuser",
        "UserPic": "/UserPic/testuser.png",
        "MemberSince": "2019-03-15 10:30:00",
        "TotalPoints": 1500,
        "TotalSoftcorePoints": 800,
        "TotalTruePoints": 4200,
        "ContribCount": 5,
        "ContribYield": 100,
        "Permissions": 1,
        "ID": 12345,
        "Motto": "Retro gaming forever"
    }
    """.data(using: .utf8)!

    await mockSession.enqueueResponse(data: loginData)
    await mockSession.enqueueResponse(data: fullProfileData)

    let client = RetroAchievementsClient(urlSession: mockSession)
    let session = try await client.login(username: "testuser", password: "testpass")

    #expect(session.user.user == "testuser")
    #expect(session.token == "auth_token_12345")
    #expect(session.user.totalPoints == 1500)
    #expect(session.user.totalTruePoints == 4200)
    #expect(session.user.memberSince == "2019-03-15 10:30:00")
    #expect(session.user.contribCount == 5)
    #expect(session.user.contribYield == 100)
    #expect(session.user.motto == "Retro gaming forever")
    #expect(session.user.id == 12345)
}

/// Verifies login still succeeds even if the full profile fetch fails,
/// falling back to the partial profile from the login response
@Test func testLoginFallsBackToPartialProfileOnFetchFailure() async throws {
    RetroCredentialsManager.shared.clearAll()
    let mockSession = MockURLSession()

    let loginData = """
    {
        "Success": true,
        "User": "testuser",
        "Token": "auth_token_12345",
        "Score": 500,
        "SoftcoreScore": 200
    }
    """.data(using: .utf8)!

    await mockSession.enqueueResponse(data: loginData)
    await mockSession.enqueueResponse(data: Data(), statusCode: 500)

    let client = RetroAchievementsClient(urlSession: mockSession)
    let session = try await client.login(username: "testuser", password: "testpass")

    #expect(session.user.user == "testuser")
    #expect(session.user.totalPoints == 500)
    #expect(session.user.totalSoftcorePoints == 200)
    // These should be nil since the full profile fetch failed
    #expect(session.user.memberSince == nil)
    #expect(session.user.totalTruePoints == nil)
    #expect(session.user.contribCount == nil)
}

/// Verifies login with wrong password throws authenticationFailed
@Test func testLoginFailure() async {
    RetroCredentialsManager.shared.clearAll()
    let mockSession = MockURLSession()
    let loginData = """
    {
        "Success": false,
        "User": null,
        "Token": null
    }
    """.data(using: .utf8)!

    mockSession.setMockResponse(data: loginData)

    let client = RetroAchievementsClient(urlSession: mockSession)

    do {
        _ = try await client.login(username: "testuser", password: "wrongpass")
        #expect(Bool(false), "Should have thrown an error")
    } catch let error as RetroError {
        if case .authenticationFailed = error {
            // Expected
        } else {
            #expect(Bool(false), "Expected authenticationFailed error, got \(error)")
        }
    } catch {
        #expect(Bool(false), "Expected RetroError")
    }
}

/// Verifies the PVCheevos.login convenience method works
@Test func testPVCheevosLoginMethod() async throws {
    RetroCredentialsManager.shared.clearAll()
    let mockSession = MockURLSession()

    let loginData = """
    {
        "Success": true,
        "User": "testuser",
        "Token": "auth_token_12345",
        "Score": 1500
    }
    """.data(using: .utf8)!

    let fullProfileData = """
    {
        "User": "testuser",
        "TotalPoints": 1500,
        "MemberSince": "2020-06-01 00:00:00",
        "TotalTruePoints": 3000
    }
    """.data(using: .utf8)!

    await mockSession.enqueueResponse(data: loginData)
    await mockSession.enqueueResponse(data: fullProfileData)

    let client = try await PVCheevos.login(
        username: "testuser",
        password: "testpass",
        urlSession: mockSession
    )

    let isAuth = await client.isAuthenticated
    #expect(isAuth == true)

    let username = await client.currentUsername
    #expect(username == "testuser")
}

// MARK: - Web API Key Auth Tests

/// Verifies that a client created with web API key can call getUserProfile
@Test func testWebAPIKeyAuthFetchesProfile() async throws {
    let mockSession = MockURLSession()
    let profileData = """
    {
        "User": "testuser",
        "TotalPoints": 2500,
        "TotalTruePoints": 7500,
        "MemberSince": "2018-05-20 14:00:00",
        "ContribCount": 0,
        "ContribYield": 0,
        "ID": 99999,
        "Motto": "Hello world"
    }
    """.data(using: .utf8)!

    mockSession.setMockResponse(data: profileData)

    let client = PVCheevos.client(username: "testuser", webAPIKey: "my_api_key", urlSession: mockSession)
    let profile = try await client.getUserProfile(username: "testuser")

    #expect(profile.user == "testuser")
    #expect(profile.totalPoints == 2500)
    #expect(profile.totalTruePoints == 7500)
    #expect(profile.memberSince == "2018-05-20 14:00:00")
    #expect(profile.contribCount == 0)
    #expect(profile.id == 99999)
}

/// Verifies that a client without any credentials throws authenticationFailed
@Test func testNoCredentialsThrowsAuth() async {
    RetroCredentialsManager.shared.clearAll()
    let mockSession = MockURLSession()
    mockSession.setMockResponse(data: Data())

    let client = RetroAchievementsClient(urlSession: mockSession)

    do {
        _ = try await client.getUserProfile(username: "testuser")
        #expect(Bool(false), "Should have thrown an error")
    } catch let error as RetroError {
        if case .authenticationFailed = error {
            // Expected
        } else {
            #expect(Bool(false), "Expected authenticationFailed error, got \(error)")
        }
    } catch {
        #expect(Bool(false), "Expected RetroError")
    }
}

// MARK: - Model Tests
@Test func testUserProfileDecoding() throws {
    let json = """
    {
        "User": "TestUser",
        "UserPic": "/UserPic/TestUser.png",
        "MemberSince": "2020-01-01 12:00:00",
        "TotalPoints": 15000,
        "TotalSoftcorePoints": 5000,
        "TotalTruePoints": 42000,
        "ContribCount": 10,
        "ContribYield": 250,
        "ID": 12345,
        "Motto": "Gaming is life"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let profile = try decoder.decode(UserProfile.self, from: json)

    #expect(profile.user == "TestUser")
    #expect(profile.userPic == "/UserPic/TestUser.png")
    #expect(profile.memberSince == "2020-01-01 12:00:00")
    #expect(profile.totalPoints == 15000)
    #expect(profile.totalSoftcorePoints == 5000)
    #expect(profile.totalTruePoints == 42000)
    #expect(profile.contribCount == 10)
    #expect(profile.contribYield == 250)
    #expect(profile.id == 12345)
    #expect(profile.motto == "Gaming is life")
}

/// Verifies that a profile with minimal fields (like from login) decodes correctly
@Test func testUserProfileDecodingPartial() throws {
    let json = """
    {
        "User": "MinimalUser",
        "TotalPoints": 100
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let profile = try decoder.decode(UserProfile.self, from: json)

    #expect(profile.user == "MinimalUser")
    #expect(profile.totalPoints == 100)
    #expect(profile.memberSince == nil)
    #expect(profile.totalTruePoints == nil)
    #expect(profile.contribCount == nil)
    #expect(profile.contribYield == nil)
}

@Test func testAchievementDecoding() throws {
    let json = """
    {
        "ID": 12345,
        "Title": "First Steps",
        "Description": "Complete the tutorial",
        "Points": 5,
        "TrueRatio": 10,
        "Author": "GameDev",
        "BadgeName": "12345",
        "NumAwarded": 1000,
        "NumAwardedHardcore": 800
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let achievement = try decoder.decode(Achievement.self, from: json)

    #expect(achievement.id == 12345)
    #expect(achievement.title == "First Steps")
    #expect(achievement.description == "Complete the tutorial")
    #expect(achievement.points == 5)
    #expect(achievement.trueRatio == 10)
    #expect(achievement.author == "GameDev")
    #expect(achievement.badgeName == "12345")
    #expect(achievement.numAwarded == 1000)
    #expect(achievement.numAwardedHardcore == 800)
}

@Test func testGameDecoding() throws {
    let json = """
    {
        "ID": 1,
        "Title": "Super Mario Bros.",
        "ConsoleID": 7,
        "ConsoleName": "NES",
        "ImageIcon": "/Images/001234.png",
        "Publisher": "Nintendo",
        "Developer": "Nintendo",
        "Genre": "Platform",
        "Released": "1985",
        "NumAchievements": 30
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let game = try decoder.decode(Game.self, from: json)

    #expect(game.id == 1)
    #expect(game.title == "Super Mario Bros.")
    #expect(game.consoleID == 7)
    #expect(game.consoleName == "NES")
    #expect(game.imageIcon == "/Images/001234.png")
    #expect(game.publisher == "Nintendo")
    #expect(game.developer == "Nintendo")
    #expect(game.genre == "Platform")
    #expect(game.released == "1985")
    #expect(game.numAchievements == 30)
}

@Test func testCommentDecoding() throws {
    let json = """
    {
        "User": "TestUser",
        "Submitted": "2023-01-01 12:00:00",
        "CommentText": "Great achievement!"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let comment: RAComment = try decoder.decode(RAComment.self, from: json)

    #expect(comment.user == "TestUser")
    #expect(comment.submitted == "2023-01-01 12:00:00")
    #expect(comment.commentText == "Great achievement!")
}

@Test func testLoginResponseDecoding() throws {
    let json = """
    {
        "Success": true,
        "User": "testuser",
        "AvatarUrl": "/UserPic/testuser.png",
        "Token": "abc123",
        "Score": 9999,
        "SoftcoreScore": 1234,
        "Messages": 3,
        "Permissions": 1,
        "AccountType": "Registered"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let response = try decoder.decode(LoginResponse.self, from: json)

    #expect(response.success == true)
    #expect(response.user == "testuser")
    #expect(response.avatarUrl == "/UserPic/testuser.png")
    #expect(response.token == "abc123")
    #expect(response.score == 9999)
    #expect(response.softcoreScore == 1234)
    #expect(response.messages == 3)
    #expect(response.permissions == 1)
    #expect(response.accountType == "Registered")
}

// MARK: - Integration Tests
@Test func testGetGameWithAchievements() async throws {
    let mockSession = MockURLSession()
    let testData = """
    {
        "ID": 1,
        "Title": "Test Game",
        "ConsoleID": 1,
        "ConsoleName": "Test Console",
        "NumAchievements": 2,
        "Achievements": {
            "1": {
                "ID": 1,
                "Title": "First Achievement",
                "Points": 5
            },
            "2": {
                "ID": 2,
                "Title": "Second Achievement",
                "Points": 10
            }
        }
    }
    """.data(using: .utf8)!

    mockSession.setMockResponse(data: testData)

    let credentials = RetroCredentials.webAPIKey(username: "testuser", webAPIKey: "testkey")
    let client = RetroAchievementsClient(credentials: credentials, urlSession: mockSession)

    let game = try await client.getGame(gameId: 1)

    #expect(game.id == 1)
    #expect(game.title == "Test Game")
    #expect(game.numAchievements == 2)
    #expect(game.achievements?.count == 2)

    let firstAchievement = game.achievements?["1"]
    #expect(firstAchievement?.title == "First Achievement")
    #expect(firstAchievement?.points == 5)
}

/// Verifies the full login → profile fetch → session check round trip
@Test func testLoginToSessionRoundTrip() async throws {
    RetroCredentialsManager.shared.clearAll()
    let mockSession = MockURLSession()

    let loginData = """
    {
        "Success": true,
        "User": "roundtrip_user",
        "Token": "rt_token_abc",
        "Score": 300,
        "SoftcoreScore": 50
    }
    """.data(using: .utf8)!

    let fullProfileData = """
    {
        "User": "roundtrip_user",
        "TotalPoints": 300,
        "TotalSoftcorePoints": 50,
        "TotalTruePoints": 900,
        "MemberSince": "2021-11-01 08:00:00",
        "ContribCount": 0,
        "ContribYield": 0,
        "UserPic": "/UserPic/roundtrip_user.png",
        "ID": 54321
    }
    """.data(using: .utf8)!

    await mockSession.enqueueResponse(data: loginData)
    await mockSession.enqueueResponse(data: fullProfileData)

    let client = RetroAchievementsClient(urlSession: mockSession)

    let isAuthBefore = await client.isAuthenticated
    #expect(isAuthBefore == false)

    let session = try await client.login(username: "roundtrip_user", password: "pass123")

    let isAuthAfter = await client.isAuthenticated
    #expect(isAuthAfter == true)

    #expect(session.user.user == "roundtrip_user")
    #expect(session.user.totalTruePoints == 900)
    #expect(session.user.memberSince == "2021-11-01 08:00:00")
    #expect(session.user.id == 54321)
    #expect(session.token == "rt_token_abc")
}
