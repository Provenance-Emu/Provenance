import UIKit

/// Mock implementation of DeltaSkinProtocol for testing
public struct MockDeltaSkin: DeltaSkinProtocol {

    public let identifier: String
    public let name: String
    public let gameType: DeltaSkinGameType
    public let fileURL: URL
    public let isDebugEnabled: Bool

    private let mockRepresentation: DeltaSkin.RepresentationInfo
    private let mockImage: UIImage
    private let mockScreens: [DeltaSkinScreen]
    private let mockScreenGroups: [DeltaSkinScreenGroup]
    private let mockButtons: [DeltaSkinButton]
    private let mockMappingSize: CGSize?

    /// Initialize with test values
    public init(
        identifier: String = "com.test.gba",
        name: String = "Test GBA",
        gameType: DeltaSkinGameType = .gba,
        fileURL: URL = URL(fileURLWithPath: "/tmp/test.deltaskin"),
        isDebugEnabled: Bool = false
    ) {
        self.identifier = identifier
        self.name = name
        self.gameType = gameType
        self.fileURL = fileURL
        self.isDebugEnabled = isDebugEnabled

        // Create mock screen info
        let screenInfo = try! JSONDecoder().decode(DeltaSkin.ScreenInfo.self, from: """
        {
            "inputFrame": {
                "x": 0,
                "y": 0,
                "width": 240,
                "height": 160
            },
            "outputFrame": {
                "x": 0,
                "y": 50,
                "width": 414,
                "height": 276
            },
            "placement": "controller"
        }
        """.data(using: .utf8)!)

        // Create mock orientation representation
        let standardPortrait = try! JSONDecoder().decode(DeltaSkin.OrientationRepresentations.self, from: """
        {
            "assets": {
                "resizable": "test.pdf"
            },
            "items": [],
            "screens": [{
                "inputFrame": {
                    "x": 0,
                    "y": 0,
                    "width": 240,
                    "height": 160
                },
                "outputFrame": {
                    "x": 0,
                    "y": 50,
                    "width": 414,
                    "height": 276
                },
                "placement": "controller"
            }],
            "mappingSize": {
                "width": 414,
                "height": 896
            },
            "translucent": false
        }
        """.data(using: .utf8)!)

        // Create mock screen
        self.mockScreens = [
            DeltaSkinScreen(
                id: "\(identifier)-screen-0",
                inputFrame: screenInfo.inputFrame,
                outputFrame: screenInfo.outputFrame,
                placement: screenInfo.placement ?? .controller,
                filters: []
            )
        ]

        // Create mock screen group
        self.mockScreenGroups = [
            DeltaSkinScreenGroup(
                id: "\(identifier)-screens",
                screens: self.mockScreens,
                extendedEdges: .zero,
                translucent: false,
                gameScreenFrame: nil
            )
        ]

        // Create mock buttons
        self.mockButtons = [
            DeltaSkinButton(
                id: "\(identifier)-button-0",
                input: .single("A"),
                frame: CGRect(x: 0.7, y: 0.7, width: 0.2, height: 0.1),
                extendedEdges: .zero
            )
        ]

        // Create mock representation info
        self.mockRepresentation = standardPortrait.toRepresentationInfo()

        // Set mock mapping size
        self.mockMappingSize = standardPortrait.mappingSize

        // Create default test image
        self.mockImage = UIImage()
    }

    /// Mock JSON representation
    public var jsonRepresentation: [String: Any] {
        return [
            "name": name,
            "identifier": identifier,
            "gameTypeIdentifier": gameType.rawValue,
            "debug": isDebugEnabled,
            "representations": [
                "iphone": [
                    "standard": [
                        "portrait": [
                            "assets": [
                                "resizable": "test.pdf"
                            ],
                            "items": [],
                            "screens": [
                                [
                                    "inputFrame": [
                                        "x": 0,
                                        "y": 0,
                                        "width": 240,
                                        "height": 160
                                    ],
                                    "outputFrame": [
                                        "x": 0,
                                        "y": 50,
                                        "width": 414,
                                        "height": 276
                                    ],
                                    "placement": "controller"
                                ]
                            ],
                            "mappingSize": [
                                "width": 414,
                                "height": 896
                            ],
                            "translucent": false
                        ]
                    ]
                ]
            ]
        ]
    }

    public func supports(_ traits: DeltaSkinTraits) -> Bool {
        return true
    }

    public func screens(for traits: DeltaSkinTraits) -> [DeltaSkinScreen]? {
        return mockScreens
    }

    public func screenGroups(for traits: DeltaSkinTraits) -> [DeltaSkinScreenGroup]? {
        return mockScreenGroups
    }

    public func buttons(for traits: DeltaSkinTraits) -> [DeltaSkinButton]? {
        return mockButtons
    }

    public func mappingSize(for traits: DeltaSkinTraits) -> CGSize? {
        return mockMappingSize
    }

    public func image(for traits: DeltaSkinTraits) async throws -> UIImage {
        return mockImage
    }

    public func representation(for traits: DeltaSkinTraits) -> DeltaSkin.RepresentationInfo? {
        // For testing, return a basic representation
        return DeltaSkin.RepresentationInfo(
            assets: DeltaSkin.AssetRepresentation(
                resizable: "mock.pdf",
                small: nil,
                medium: nil,
                large: nil
            ),
            mappingSize: CGSize(width: 750, height: 1334),
            translucent: false,
            screens: nil,
            items: [],
            extendedEdges: nil,
            gameScreenFrame: nil
        )
    }
}
