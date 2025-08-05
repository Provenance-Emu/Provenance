import Testing
import Foundation
@testable import PVCheevos

/// Mock URLSession for testing network requests
@available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    var mockData: Data?
    var mockResponse: HTTPURLResponse?
    var mockError: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
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
}

// MARK: - Credentials Tests
@Test func testCredentialsCreation() {
    let credentials = RetroCredentials.webAPIKey(username: "testuser", webAPIKey: "testkey")
    #expect(credentials.username == "testuser")

    let passwordCredentials = RetroCredentials.usernamePassword(username: "testuser", password: "testpass")
    #expect(passwordCredentials.username == "testuser")

    let authenticatedCredentials = RetroCredentials.authenticated(username: "testuser", token: "testtoken")
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
    // Just testing that the client can be created without errors
    #expect(client != nil)
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
@Test func testUsernamePasswordLogin() async throws {
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

    mockSession.setMockResponse(data: loginData)

    let credentials = RetroCredentials.usernamePassword(username: "testuser", password: "testpass")
    let client = RetroAchievementsClient(credentials: credentials, urlSession: mockSession)

    let session = try await client.login(username: "testuser", password: "testpass")

    #expect(session.username == "testuser")
    #expect(session.token == "auth_token_12345")
    #expect(session.score == 1500)
    #expect(session.softcoreScore == 800)
    #expect(session.permissions == 1)
    #expect(session.accountType == "Registered")
}

@Test func testLoginFailure() async {
    let mockSession = MockURLSession()
    let loginData = """
    {
        "Success": false,
        "User": null,
        "Token": null
    }
    """.data(using: .utf8)!

    mockSession.setMockResponse(data: loginData)

    let credentials = RetroCredentials.usernamePassword(username: "testuser", password: "wrongpass")
    let client = RetroAchievementsClient(credentials: credentials, urlSession: mockSession)

    do {
        _ = try await client.login(username: "testuser", password: "wrongpass")
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

@Test func testPVCheevosLoginMethod() async throws {
    let mockSession = MockURLSession()
    let loginData = """
    {
        "Success": true,
        "User": "testuser",
        "Token": "auth_token_12345",
        "Score": 1500
    }
    """.data(using: .utf8)!

    mockSession.setMockResponse(data: loginData)

    let (client, session) = try await PVCheevos.login(
        username: "testuser",
        password: "testpass",
        urlSession: mockSession
    )

    #expect(session.username == "testuser")
    #expect(session.token == "auth_token_12345")
    #expect(client != nil)
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
    #expect(profile.id == 12345)
    #expect(profile.motto == "Gaming is life")
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
