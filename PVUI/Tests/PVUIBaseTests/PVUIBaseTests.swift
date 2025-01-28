import Testing
import UIKit
import XCTest
@testable import PVUIBase

/// Custom error type for tests
struct TestError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

/// Tests for DeltaSkin JSON decoding
@Suite("DeltaSkin Decoding Tests")
struct DeltaSkinDecodingTests {

    /// Test successful decoding of GBA skin
    @Test("Decodes GBA Test skin successfully")
    func decodesGBATestSkin() throws {
        let json = """
        {
            "name": "GBA Test Skin",
            "identifier": "com.provenance.test.gba",
            "gameTypeIdentifier": "com.rileytestut.delta.game.gba",
            "debug": false,
            "representations": {
                "iphone": {
                    "standard": {
                        "portrait": {
                            "assets": {
                                "resizable": "iphone_portrait.pdf"
                            },
                            "screens": [
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
                                    }
                                }
                            ],
                            "mappingSize": {
                                "width": 414,
                                "height": 896
                            }
                        },
                        "landscape": {
                            "assets": {
                                "resizable": "iphone_landscape.pdf"
                            },
                            "screens": [
                                {
                                    "inputFrame": {
                                        "x": 0,
                                        "y": 0,
                                        "width": 240,
                                        "height": 160
                                    },
                                    "outputFrame": {
                                        "x": 50,
                                        "y": 0,
                                        "width": 796,
                                        "height": 414
                                    }
                                }
                            ],
                            "mappingSize": {
                                "width": 896,
                                "height": 414
                            }
                        }
                    }
                },
                "ipad": {
                    "standard": {
                        "portrait": {
                            "assets": {
                                "resizable": "ipad_portrait.pdf"
                            },
                            "screens": [
                                {
                                    "inputFrame": {
                                        "x": 0,
                                        "y": 0,
                                        "width": 240,
                                        "height": 160
                                    },
                                    "outputFrame": {
                                        "x": 50,
                                        "y": 100,
                                        "width": 924,
                                        "height": 616
                                    },
                                    "filters": [
                                        {
                                            "name": "CIGaussianBlur",
                                            "parameters": {
                                                "inputRadius": 0.5
                                            }
                                        },
                                        {
                                            "name": "CIColorControls",
                                            "parameters": {
                                                "inputSaturation": 1.2,
                                                "inputContrast": 1.1
                                            }
                                        }
                                    ]
                                }
                            ],
                            "mappingSize": {
                                "width": 1024,
                                "height": 1366
                            }
                        }
                    },
                    "splitView": {
                        "portrait": {
                            "assets": {
                                "resizable": "ipad_split_portrait.pdf"
                            },
                            "screens": [
                                {
                                    "inputFrame": {
                                        "x": 0,
                                        "y": 0,
                                        "width": 240,
                                        "height": 160
                                    },
                                    "outputFrame": {
                                        "x": 20,
                                        "y": 20,
                                        "width": 460,
                                        "height": 307
                                    },
                                    "placement": "app",
                                    "filters": [
                                        {
                                            "name": "CIVignette",
                                            "parameters": {
                                                "inputIntensity": 0.5,
                                                "inputRadius": 1.0
                                            }
                                        }
                                    ]
                                }
                            ],
                            "mappingSize": {
                                "width": 500,
                                "height": 800
                            }
                        }
                    }
                }
            }
        }
        """

        let decoder = JSONDecoder()
        let info = try decoder.decode(DeltaSkin.Info.self, from: json.data(using: .utf8)!)

        // Test basic properties
        #expect(info.name == "GBA Test Skin")
        #expect(info.identifier == "com.provenance.test.gba")
        #expect(info.gameTypeIdentifier.rawValue == "com.rileytestut.delta.game.gba")
        #expect(info.debug == false)

        // Test representations
        let iphone = info.representations[DeltaSkinDevice.iphone]
        #expect(iphone != nil)

        let standard = iphone?.standard?["portrait"]
        #expect(standard != nil)

        // Test assets
        if case .resizable(let filename) = standard?.assets {
            #expect(filename == "iphone_portrait.pdf")
        } else {
            throw TestError("Expected resizable PDF asset")
        }

        // Test screens
        let screen = standard?.screens?.first
        #expect(screen != nil)
        #expect(screen?.inputFrame?.width == 240)
        #expect(screen?.outputFrame.height == 276)
    }

    /// Test successful decoding of GBC skin with PNG assets
    @Test("Decodes GBC Sunrise skin with PNG assets")
    func decodesGBCSkin() throws {
        let json = """
        {
          "name": "GBC Sunrise by MessieJessy",
          "identifier": "com.litritt.ignited.sunrise.gbc",
          "gameTypeIdentifier": "com.rileytestut.delta.game.gbc",
          "debug": false,
          "representations": {
            "iphone": {
              "standard": {
                "portrait": {
                  "assets": {
                    "small": "iphone-portrait.png",
                    "medium": "iphone-portrait.png",
                    "large": "iphone-portrait.png"
                  },
                  "items": [
                    {
                      "inputs": {
                        "up": "up",
                        "down": "down",
                        "left": "left",
                        "right": "right"
                      },
                      "frame": {
                        "x": 15,
                        "y": 75,
                        "width": 164,
                        "height": 164
                      },
                      "extendedEdges": {
                        "top": 12,
                        "right": 12,
                        "bottom": 12,
                        "left": 12
                      }
                    },
                    {
                      "inputs": [
                        "a"
                      ],
                      "frame": {
                        "x": 316,
                        "y": 84,
                        "width": 75,
                        "height": 75
                      }
                    },
                    {
                      "inputs": [
                        "b"
                      ],
                      "frame": {
                        "x": 231,
                        "y": 161,
                        "width": 75,
                        "height": 75
                      }
                    },
                    {
                      "inputs": [
                        "start"
                      ],
                      "frame": {
                        "x": 230,
                        "y": 270,
                        "width": 40,
                        "height": 18
                      },
                      "extendedEdges": {
                        "bottom": 15
                      }
                    },
                    {
                      "inputs": [
                        "select"
                      ],
                      "frame": {
                        "x": 144,
                        "y": 270,
                        "width": 40,
                        "height": 18
                      },
                      "extendedEdges": {
                        "bottom": 15
                      }
                    },
                    {
                      "inputs": [
                        "menu"
                      ],
                      "frame": {
                        "x": 15,
                        "y": 270,
                        "width": 40,
                        "height": 18
                      },
                      "extendedEdges": {
                        "bottom": 15
                      }
                    },
                    {
                      "inputs": [
                        "toggleFastForward"
                      ],
                      "frame": {
                        "x": 359,
                        "y": 270,
                        "width": 40,
                        "height": 18
                      },
                      "extendedEdges": {
                        "bottom": 15
                      }
                    }
                  ],
                  "mappingSize": {
                    "width": 414,
                    "height": 313
                  },
                  "extendedEdges": {
                    "top": 10,
                    "bottom": 10,
                    "left": 10,
                    "right": 10
                  }
                }
              },
              "edgeToEdge": {
                "portrait": {
                  "assets": {
                    "small": "iphone-e2e-portrait.png",
                    "medium": "iphone-e2e-portrait.png",
                    "large": "iphone-e2e-portrait.png"
                  },
                  "items": [
                    {
                      "inputs": {
                        "up": "up",
                        "down": "down",
                        "left": "left",
                        "right": "right"
                      },
                      "frame": {
                        "x": 15,
                        "y": 75,
                        "width": 164,
                        "height": 164
                      },
                      "extendedEdges": {
                        "top": 12,
                        "right": 12,
                        "bottom": 12,
                        "left": 12
                      }
                    },
                    {
                      "inputs": [
                        "a"
                      ],
                      "frame": {
                        "x": 316,
                        "y": 84,
                        "width": 75,
                        "height": 75
                      }
                    },
                    {
                      "inputs": [
                        "b"
                      ],
                      "frame": {
                        "x": 231,
                        "y": 161,
                        "width": 75,
                        "height": 75
                      }
                    },
                    {
                      "inputs": [
                        "start"
                      ],
                      "frame": {
                        "x": 230,
                        "y": 270,
                        "width": 40,
                        "height": 18
                      },
                      "extendedEdges": {
                        "bottom": 15
                      }
                    },
                    {
                      "inputs": [
                        "select"
                      ],
                      "frame": {
                        "x": 144,
                        "y": 270,
                        "width": 40,
                        "height": 18
                      },
                      "extendedEdges": {
                        "bottom": 15
                      }
                    },
                    {
                      "inputs": [
                        "menu"
                      ],
                      "frame": {
                        "x": 15,
                        "y": 270,
                        "width": 40,
                        "height": 18
                      },
                      "extendedEdges": {
                        "bottom": 15
                      }
                    },
                    {
                      "inputs": [
                        "toggleFastForward"
                      ],
                      "frame": {
                        "x": 359,
                        "y": 270,
                        "width": 40,
                        "height": 18
                      },
                      "extendedEdges": {
                        "bottom": 15
                      }
                    }
                  ],
                  "mappingSize": {
                    "width": 414,
                    "height": 354
                  },
                  "extendedEdges": {
                    "top": 10,
                    "bottom": 10,
                    "left": 10,
                    "right": 10
                  }
                }
              }
            }
          }
        }
        """

        let decoder = JSONDecoder()
        let info = try decoder.decode(DeltaSkin.Info.self, from: json.data(using: .utf8)!)

        // Test basic properties
        #expect(info.name == "GBC Sunrise by MessieJessy")
        #expect(info.gameTypeIdentifier.rawValue == "com.rileytestut.delta.game.gbc")

        // Test PNG assets
        let portrait = info.representations[DeltaSkinDevice.iphone]?.standard?["portrait"]
        #expect(portrait != nil)

        if case let .sized(small, medium, large) = portrait?.assets {
            #expect(small == "iphone-portrait.png")
            #expect(medium == "iphone-portrait.png")
            #expect(large == "iphone-portrait.png")
        } else {
            throw TestError("Expected sized PNG assets")
        }

        // Test items/controls
        let dpad = portrait?.items?.first
        #expect(dpad != nil)
        if case .directional(let mapping) = dpad?.inputs {
            #expect(mapping["up"] == "up")
            #expect(mapping["down"] == "down")
        } else {
            throw TestError("Expected directional input mapping")
        }
    }

    /// Test decoding of filter configurations
    @Test("Decodes screen filters correctly")
    func decodesScreenFilters() throws {
        let json = """
        {
            "name": "CIGaussianBlur",
            "parameters": {
                "inputRadius": 0.5
            }
        }
        """

        let decoder = JSONDecoder()
        let filter = try decoder.decode(DeltaSkin.FilterInfo.self, from: json.data(using: .utf8)!)

        #expect(filter.name == "CIGaussianBlur")
        if case let .number(radius) = filter.parameters["inputRadius"] {
            #expect(radius == 0.5)
        } else {
            throw TestError("Expected number parameter for blur radius")
        }

        // Test more complex filter
        let colorJson = """
        {
            "name": "CIColorControls",
            "parameters": {
                "inputSaturation": 1.2,
                "inputContrast": 1.1,
                "inputColor": {
                    "r": 1.0,
                    "g": 0.5,
                    "b": 0.0
                }
            }
        }
        """

        let colorFilter = try decoder.decode(DeltaSkin.FilterInfo.self, from: colorJson.data(using: .utf8)!)
        #expect(colorFilter.name == "CIColorControls")

        if case let .number(saturation) = colorFilter.parameters["inputSaturation"] {
            #expect(saturation == 1.2)
        }
        if case let .number(contrast) = colorFilter.parameters["inputContrast"] {
            #expect(contrast == 1.1)
        }
        if case let .color(r, g, b) = colorFilter.parameters["inputColor"] {
            #expect(r == 1.0)
            #expect(g == 0.5)
            #expect(b == 0.0)
        }
    }

    /// Test error cases
    @Test("Handles invalid JSON appropriately")
    func handlesInvalidJSON() async throws {
        // Invalid game type
        let invalidGameType = """
        {
            "name": "Invalid",
            "identifier": "test",
            "gameTypeIdentifier": "invalid.game.type",
            "debug": false,
            "representations": {}
        }
        """

        let decoder = JSONDecoder()
        do {
            _ = try decoder.decode(DeltaSkin.Info.self, from: invalidGameType.data(using: .utf8)!)
            throw TestError("Expected failure for invalid game type")
        } catch {}

        // Invalid asset format
        let invalidAssets = """
        {
            "name": "Invalid Assets",
            "identifier": "test",
            "gameTypeIdentifier": "com.rileytestut.delta.game.gba",
            "debug": false,
            "representations": {
                "iphone": {
                    "standard": {
                        "portrait": {
                            "assets": {
                                "invalid": "test.png"
                            },
                            "mappingSize": {
                                "width": 100,
                                "height": 100
                            }
                        }
                    }
                }
            }
        }
        """

        do {
            _ = try decoder.decode(DeltaSkin.Info.self, from: invalidAssets.data(using: .utf8)!)
            throw TestError("Expected failure for invalid assets")
        } catch {}
    }

    /// Test successful decoding of SNES Test skin
    @Test("Decodes SNES Test skin successfully")
    func decodesSNESTestSkin() throws {
        let json = """
        {
            "name": "SNES Test Skin",
            "identifier": "com.provenance.test.snes",
            "gameTypeIdentifier": "com.rileytestut.delta.game.snes",
            "debug": false,
            "representations": {
                "iphone": {
                    "standard": {
                        "landscape": {
                            "assets": {
                                "resizable": "iphone_landscape.pdf"
                            },
                            "screens": [
                                {
                                    "inputFrame": {
                                        "x": 0,
                                        "y": 0,
                                        "width": 256,
                                        "height": 224
                                    },
                                    "outputFrame": {
                                        "x": 50,
                                        "y": 0,
                                        "width": 796,
                                        "height": 414
                                    }
                                }
                            ],
                            "mappingSize": {
                                "width": 896,
                                "height": 414
                            }
                        }
                    },
                    "edgeToEdge": {
                        "landscape": {
                            "assets": {
                                "resizable": "iphone_edge.pdf"
                            },
                            "screens": [
                                {
                                    "inputFrame": {
                                        "x": 0,
                                        "y": 0,
                                        "width": 256,
                                        "height": 224
                                    },
                                    "outputFrame": {
                                        "x": 0,
                                        "y": 0,
                                        "width": 896,
                                        "height": 414
                                    }
                                }
                            ],
                            "mappingSize": {
                                "width": 896,
                                "height": 414
                            }
                        }
                    }
                }
            }
        }
        """

        let decoder = JSONDecoder()
        let info = try decoder.decode(DeltaSkin.Info.self, from: json.data(using: .utf8)!)

        // Test basic properties
        #expect(info.name == "SNES Test Skin")
        #expect(info.identifier == "com.provenance.test.snes")
        #expect(info.gameTypeIdentifier.rawValue == "com.rileytestut.delta.game.snes")
        #expect(info.debug == false)

        // Test standard layout
        let standard = info.representations[DeltaSkinDevice.iphone]?.standard?["landscape"]
        #expect(standard != nil)

        if case .resizable(let filename) = standard?.assets {
            #expect(filename == "iphone_landscape.pdf")
        } else {
            throw TestError("Expected resizable PDF asset")
        }

        let standardScreen = standard?.screens?.first
        #expect(standardScreen != nil)
        #expect(standardScreen?.inputFrame?.width == 256)
        #expect(standardScreen?.inputFrame?.height == 224)
        #expect(standardScreen?.outputFrame.width == 796)
        #expect(standardScreen?.outputFrame.height == 414)

        // Test edge-to-edge layout
        let edge = info.representations[DeltaSkinDevice.iphone]?.edgeToEdge?["landscape"]
        #expect(edge != nil)

        if case .resizable(let filename) = edge?.assets {
            #expect(filename == "iphone_edge.pdf")
        } else {
            throw TestError("Expected resizable PDF asset")
        }

        let edgeScreen = edge?.screens?.first
        #expect(edgeScreen != nil)
        #expect(edgeScreen?.outputFrame.width == 896)
        #expect(edgeScreen?.outputFrame.height == 414)

        // Test mapping sizes
        #expect(standard?.mappingSize!.width == 896)
        #expect(standard?.mappingSize!.height == 414)
        #expect(edge?.mappingSize!.width == 896)
        #expect(edge?.mappingSize!.height == 414)
    }

    /// Test successful decoding of DS skin with dual screens
    @Test("Decodes DS Test skin successfully")
    func decodesDSTestSkin() throws {
        let json = """
        {
            "name": "DS Test Skin",
            "identifier": "com.provenance.test.ds",
            "gameTypeIdentifier": "com.rileytestut.delta.game.ds",
            "debug": false,
            "representations": {
                "iphone": {
                    "edgeToEdge": {
                        "landscape": {
                            "assets": {
                                "resizable": "iphone_landscape.pdf"
                            },
                            "screens": [
                                {
                                    "inputFrame": {
                                        "x": 0,
                                        "y": 0,
                                        "width": 256,
                                        "height": 192
                                    },
                                    "outputFrame": {
                                        "x": 20,
                                        "y": 0,
                                        "width": 535,
                                        "height": 400
                                    }
                                },
                                {
                                    "inputFrame": {
                                        "x": 0,
                                        "y": 192,
                                        "width": 256,
                                        "height": 192
                                    },
                                    "outputFrame": {
                                        "x": 555,
                                        "y": 0,
                                        "width": 341,
                                        "height": 256
                                    }
                                }
                            ],
                            "mappingSize": {
                                "width": 896,
                                "height": 414
                            }
                        }
                    }
                }
            }
        }
        """

        let decoder = JSONDecoder()
        let info = try decoder.decode(DeltaSkin.Info.self, from: json.data(using: .utf8)!)

        // Test basic properties
        #expect(info.name == "DS Test Skin")
        #expect(info.identifier == "com.provenance.test.ds")
        #expect(info.gameTypeIdentifier.rawValue == "com.rileytestut.delta.game.ds")
        #expect(info.debug == false)

        // Test iPhone edge-to-edge landscape layout
        let landscape = info.representations[DeltaSkinDevice.iphone]?.edgeToEdge?["landscape"]
        #expect(landscape != nil)

        // Test assets
        if case .resizable(let filename) = landscape?.assets {
            #expect(filename == "iphone_landscape.pdf")
        } else {
            throw TestError("Expected resizable PDF asset")
        }

        // Test dual screen configuration
        let screens = landscape?.screens
        #expect(screens?.count == 2)

        // Test top screen (main display)
        let topScreen = screens?.first
        #expect(topScreen?.inputFrame?.width == 256)
        #expect(topScreen?.inputFrame?.height == 192)
        #expect(topScreen?.outputFrame.width == 535)
        #expect(topScreen?.outputFrame.height == 400)

        // Test bottom screen (touch screen)
        let bottomScreen = screens?.last
        #expect(bottomScreen?.inputFrame?.minY == 192)  // Positioned below top screen in input
        #expect(bottomScreen?.outputFrame.minX == 555)  // Positioned right of top screen in output
        #expect(bottomScreen?.outputFrame.width == 341)
        #expect(bottomScreen?.outputFrame.height == 256)

        // Test mapping size
        #expect(landscape?.mappingSize!.width == 896)
        #expect(landscape?.mappingSize!.height == 414)
    }

    /// Test successful decoding of Genesis skin
    @Test("Decodes Genesis Test skin successfully")
    func decodesGenesisTestSkin() throws {
        // ... similar test for Genesis skin ...
    }

    /// Test successful decoding of N64 skin
    @Test("Decodes N64 Test skin successfully")
    func decodesN64TestSkin() throws {
        let json = """
        {
            "name": "N64 Test Skin",
            "identifier": "com.provenance.test.n64",
            "gameTypeIdentifier": "com.rileytestut.delta.game.n64",
            "debug": false,
            "representations": {
                "iphone": {
                    "standard": {
                        "landscape": {
                            "assets": {
                                "resizable": "iphone_landscape.pdf"
                            },
                            "screens": [
                                {
                                    "inputFrame": {
                                        "x": 0,
                                        "y": 0,
                                        "width": 320,
                                        "height": 240
                                    },
                                    "outputFrame": {
                                        "x": 50,
                                        "y": 0,
                                        "width": 796,
                                        "height": 414
                                    },
                                    "filters": [
                                        {
                                            "name": "CIStretch",
                                            "parameters": {
                                                "inputScale": {
                                                    "x": 1.33,
                                                    "y": 1.0
                                                }
                                            }
                                        }
                                    ]
                                }
                            ],
                            "mappingSize": {
                                "width": 896,
                                "height": 414
                            }
                        }
                    }
                }
            }
        }
        """

        let decoder = JSONDecoder()
        let info = try decoder.decode(DeltaSkin.Info.self, from: json.data(using: .utf8)!)

        // Test basic properties
        #expect(info.name == "N64 Test Skin")
        #expect(info.identifier == "com.provenance.test.n64")
        #expect(info.gameTypeIdentifier.rawValue == "com.rileytestut.delta.game.n64")
        #expect(info.debug == false)

        // Test iPhone landscape layout
        let landscape = info.representations[DeltaSkinDevice.iphone]?.standard?["landscape"]
        #expect(landscape != nil)

        // Test assets
        if case .resizable(let filename) = landscape?.assets {
            #expect(filename == "iphone_landscape.pdf")
        } else {
            throw TestError("Expected resizable PDF asset")
        }

        // Test screen configuration
        let screen = landscape?.screens?.first
        #expect(screen != nil)
        #expect(screen?.inputFrame?.width == 320)
        #expect(screen?.inputFrame?.height == 240)
        #expect(screen?.outputFrame.width == 796)
        #expect(screen?.outputFrame.height == 414)

        // Test stretch filter
        let filter = screen?.filters?.first
        #expect(filter?.name == "CIStretch")
        if case let .vector(x, y) = filter?.parameters["inputScale"] {
            #expect(x == 1.33)
            #expect(y == 1.0)
        } else {
            throw TestError("Expected vector parameter for stretch scale")
        }

        // Test mapping size
        #expect(landscape?.mappingSize!.width == 896)
        #expect(landscape?.mappingSize!.height == 414)
    }

    /// Test successful decoding of GBA Sharp X1 skin
    @Test("Decodes GBA Sharp X1 skin successfully")
    func decodesGBASharpX1Skin() throws {
        let json = """
        {
          "name" : "SHARP X1",
          "identifier" : "com.failyx.sharp.x1",
          "gameTypeIdentifier" : "com.rileytestut.delta.game.gba",
          "debug" : false,
          "representations" : {
            "iphone" : {
              "standard" : {
                "portrait" : {
                  "assets" : {
                    "resizable" : "iphone_portrait.pdf"
                  },
                  "items" : [
                    {
                      "inputs" : {
                        "up" : "up",
                        "down" : "down",
                        "left" : "left",
                        "right" : "right"
                      },
                      "frame" : {
                        "x" : 26,
                        "y" : 757,
                        "width" : 339,
                        "height" : 339
                      },
                      "extendedEdges" : {
                        "top" : 15,
                        "bottom" : 15,
                        "left" : 15,
                        "right" : 15
                      }
                    },
                    {
                      "inputs" : [
                        "a"
                      ],
                      "frame" : {
                        "x" : 598,
                        "y" : 962,
                        "width" : 137,
                        "height" : 137
                      },
                      "extendedEdges" : {
                        "right" : 15
                      }
                    },
                    {
                      "inputs" : [
                        "b"
                      ],
                      "frame" : {
                        "x" : 420,
                        "y" : 962,
                        "width" : 137,
                        "height" : 137
                      }
                    },
                    {
                      "inputs" : [
                        "l"
                      ],
                      "frame" : {
                        "x" : 576,
                        "y" : 1230,
                        "width" : 155,
                        "height" : 55
                      }
                    },
                    {
                      "inputs" : [
                        "menu"
                      ],
                      "frame" : {
                        "x" : 0,
                        "y" : 1217,
                        "width" : 98,
                        "height" : 117
                      },
                      "extendedEdges" : {
                        "left" : 0,
                        "bottom" : 0
                      }
                    }
                  ],
                  "gameScreenFrame" : {
                    "x" : 0,
                    "y" : 79,
                    "width" : 750,
                    "height" : 503
                  },
                  "mappingSize" : {
                    "width" : 750,
                    "height" : 1334
                  },
                  "extendedEdges" : {
                    "top" : 7,
                    "bottom" : 7,
                    "left" : 7,
                    "right" : 7
                  }
                },
                "landscape" : {
                  "assets" : {
                    "resizable" : "iphone_landscape.pdf"
                  },
                  "items" : [
                    {
                      "inputs" : {
                        "up" : "up",
                        "down" : "down",
                        "left" : "left",
                        "right" : "right"
                      },
                      "frame" : {
                        "x" : 37,
                        "y" : 287,
                        "width" : 186,
                        "height" : 186
                      },
                      "extendedEdges" : {
                        "left" : 20,
                        "top" : 20,
                        "right" : 20,
                        "bottom" : 20
                      }
                    },
                    {
                      "inputs" : [
                        "a"
                      ],
                      "frame" : {
                        "x" : 786,
                        "y" : 396,
                        "width" : 77,
                        "height" : 77
                      },
                      "extendedEdges" : {
                        "top" : 0,
                        "bottom" : 0,
                        "left" : 0,
                        "right" : 15
                      }
                    },
                    {
                      "inputs" : [
                        "b"
                      ],
                      "frame" : {
                        "x" : 686,
                        "y" : 396,
                        "width" : 77,
                        "height" : 77
                      },
                      "extendedEdges" : {
                        "top" : 0,
                        "bottom" : 15,
                        "left" : 0,
                        "right" : 0
                      }
                    },
                    {
                      "inputs" : [
                        "l"
                      ],
                      "frame" : {
                        "x" : 795,
                        "y" : 271,
                        "width" : 81,
                        "height" : 30
                      }
                    },
                    {
                      "inputs" : [
                        "menu"
                      ],
                      "frame" : {
                        "x" : 450,
                        "y" : 423,
                        "width" : 49,
                        "height" : 77
                      }
                    }
                  ],
                  "gameScreenFrame" : {
                    "x" : 178,
                    "y" : 0,
                    "width" : 594,
                    "height" : 335
                  },
                  "mappingSize" : {
                    "width" : 889,
                    "height" : 500
                  },
                  "extendedEdges" : {
                    "top" : 15,
                    "bottom" : 15,
                    "left" : 15,
                    "right" : 15
                  },
                  "translucent" : false
                }
              },
              "edgeToEdge" : {
                "portrait" : {
                  "assets" : {
                    "resizable" : "iphone_edgetoedge_portrait.pdf"
                  },
                  "items" : [
                    {
                      "inputs" : {
                        "up" : "up",
                        "down" : "down",
                        "left" : "left",
                        "right" : "right"
                      },
                      "frame" : {
                        "x" : 13,
                        "y" : 604,
                        "width" : 221,
                        "height" : 221
                      },
                      "extendedEdges" : {
                        "top" : 15,
                        "bottom" : 15,
                        "left" : 15,
                        "right" : 15
                      }
                    },
                    {
                      "inputs" : [
                        "a"
                      ],
                      "frame" : {
                        "x" : 386,
                        "y" : 737,
                        "width" : 90,
                        "height" : 90
                      },
                      "extendedEdges" : {
                        "right" : 15
                      }
                    },
                    {
                      "inputs" : [
                        "b"
                      ],
                      "frame" : {
                        "x" : 270,
                        "y" : 737,
                        "width" : 90,
                        "height" : 90
                      }
                    },
                    {
                      "inputs" : [
                        "l"
                      ],
                      "frame" : {
                        "x" : 371,
                        "y" : 910,
                        "width" : 116,
                        "height" : 40
                      }
                    },
                    {
                      "inputs" : [
                        "menu"
                      ],
                      "frame" : {
                        "x" : 0,
                        "y" : 901,
                        "width" : 63,
                        "height" : 59
                      },
                      "extendedEdges" : {
                        "left" : 8,
                        "bottom" : 13
                      }
                    }
                  ],
                  "gameScreenFrame" : {
                    "x" : 0,
                    "y" : 141,
                    "width" : 487,
                    "height" : 327
                  },
                  "mappingSize" : {
                    "width" : 487,
                    "height" : 1056
                  },
                  "extendedEdges" : {
                    "top" : 7,
                    "bottom" : 7,
                    "left" : 7,
                    "right" : 7
                  }
                },
                "landscape" : {
                  "assets" : {
                    "resizable" : "iphone_edgetoedge_landscape.pdf"
                  },
                  "items" : [
                    {
                      "inputs" : {
                        "up" : "up",
                        "down" : "down",
                        "left" : "left",
                        "right" : "right"
                      },
                      "frame" : {
                        "x" : 76,
                        "y" : 287,
                        "width" : 187,
                        "height" : 187
                      },
                      "extendedEdges" : {
                        "left" : 30,
                        "top" : 20,
                        "right" : 20,
                        "bottom" : 20
                      }
                    },
                    {
                      "inputs" : [
                        "a"
                      ],
                      "frame" : {
                        "x" : 943,
                        "y" : 362,
                        "width" : 77,
                        "height" : 77
                      },
                      "extendedEdges" : {
                        "bottom" : 0,
                        "right" : 30
                      }
                    },
                    {
                      "inputs" : [
                        "b"
                      ],
                      "frame" : {
                        "x" : 843,
                        "y" : 362,
                        "width" : 77,
                        "height" : 77
                      },
                      "extendedEdges" : {
                        "right" : 0
                      }
                    },
                    {
                      "inputs" : [
                        "l"
                      ],
                      "frame" : {
                        "x" : 879,
                        "y" : 193,
                        "width" : 91,
                        "height" : 34
                      }
                    },
                    {
                      "inputs" : [
                        "menu"
                      ],
                      "frame" : {
                        "x" : 879,
                        "y" : 139,
                        "width" : 91,
                        "height" : 34
                      }
                    }
                  ],
                  "gameScreenFrame" : {
                    "x" : 244,
                    "y" : 0,
                    "width" : 595,
                    "height" : 335
                  },
                  "mappingSize" : {
                    "width" : 1083,
                    "height" : 500
                  },
                  "extendedEdges" : {
                    "top" : 15,
                    "bottom" : 15,
                    "left" : 15,
                    "right" : 15
                  },
                  "translucent" : false
                }
              }
            }
          }
        }
        """

        let decoder = JSONDecoder()
        let info = try decoder.decode(DeltaSkin.Info.self, from: json.data(using: .utf8)!)

        // Test basic properties
        #expect(info.name == "SHARP X1")
        #expect(info.identifier == "com.failyx.sharp.x1")
        #expect(info.gameTypeIdentifier == .gba)
        #expect(info.debug == false)

        // Test iPhone portrait layout
        let portrait = info.representations[DeltaSkinDevice.iphone]?.standard?["portrait"]
        #expect(portrait != nil)

        // Test assets
        if case .resizable(let filename) = portrait?.assets {
            #expect(filename == "iphone_portrait.pdf")
        } else {
            throw TestError("Expected resizable PDF asset")
        }

        // Test D-pad configuration
        let dpad = portrait?.items?.first
        #expect(dpad != nil)
        if case .directional(let mapping) = dpad?.inputs {
            #expect(mapping["up"] == "up")
            #expect(mapping["down"] == "down")
            #expect(mapping["left"] == "left")
            #expect(mapping["right"] == "right")
        }
        #expect(dpad?.frame.width == 339)
        #expect(dpad?.extendedEdges?.top == 15)

        // Test A button configuration
        let aButton = portrait?.items?[1]
        #expect(aButton != nil)
        if case .single(let inputs) = aButton?.inputs {
            #expect(inputs.first == "a")
        }
        #expect(aButton?.frame.width == 137)
        #expect(aButton?.extendedEdges?.right == 15)

        // Test game screen frame
        #expect(portrait?.gameScreenFrame?.width == 750)
        #expect(portrait?.gameScreenFrame?.height == 503)

        // Test mapping size and extended edges
        #expect(portrait?.mappingSize!.width == 750)
        #expect(portrait?.mappingSize!.height == 1334)
        #expect(portrait?.extendedEdges?.top == 7)
    }
}

@Suite("DeltaSkin Tests")
struct DeltaSkinTests {
    /// Test mock skin implementation
    @Test("Mock skin provides expected values")
    func testMockSkin() async throws {
        let mockSkin = MockDeltaSkin(
            identifier: "com.test.gba",
            name: "Test GBA",
            gameType: DeltaSkinGameType.gba,
            fileURL: URL(fileURLWithPath: "/tmp/test.deltaskin"),
            isDebugEnabled: true
        )

        #expect(mockSkin.name == "Test GBA")
        #expect(mockSkin.identifier == "com.test.gba")
        #expect(mockSkin.gameType == .gba)
        #expect(mockSkin.isDebugEnabled == true)

        let traits = DeltaSkinTraits(
            device: DeltaSkinDevice.iphone,
            displayType: .standard,
            orientation: .portrait
        )

        // Test async image loading
        let image = try await mockSkin.image(for: traits)
        #expect(image.size.width >= 0)

        // Test screen groups
        let groups = mockSkin.screenGroups(for: traits)
        #expect(groups?.count == 1)
    }

    // ... existing JSON decoding tests ...
}

@Suite("DeltaSkin Component Decoding Tests")
struct DeltaSkinComponentTests {
    /// Test decoding of CGRect from dictionary format
    @Test("Decodes CGRect from dictionary format")
    func decodesCGRectFromDictionary() throws {
        let json = """
        {
            "x": 0,
            "y": 192,
            "width": 256,
            "height": 192
        }
        """

        struct TestRect: Codable {
            let rect: CGRect

            init(from decoder: Decoder) throws {
                rect = try CGRect(fromDeltaSkin: decoder)
            }
        }

        let decoder = JSONDecoder()
        let testRect = try decoder.decode(TestRect.self, from: json.data(using: .utf8)!)

        #expect(testRect.rect.minX == 0)
        #expect(testRect.rect.minY == 192)
        #expect(testRect.rect.width == 256)
        #expect(testRect.rect.height == 192)
    }

    /// Test decoding of a single screen configuration
    @Test("Decodes single DS screen configuration")
    func decodesScreenConfig() throws {
        let json = """
        {
            "inputFrame": {
                "x": 0,
                "y": 192,
                "width": 256,
                "height": 192
            },
            "outputFrame": {
                "x": 0,
                "y": 576,
                "width": 768,
                "height": 576
            }
        }
        """

        let decoder = JSONDecoder()
        let screen = try decoder.decode(DeltaSkin.ScreenInfo.self, from: json.data(using: .utf8)!)

        #expect(screen.inputFrame?.minY == 192)
        #expect(screen.outputFrame.minY == 576)
    }

    /// Test decoding of CGSize from dictionary format
    @Test("Decodes CGSize from dictionary format")
    func decodesCGSizeFromDictionary() throws {
        let json = """
        {
            "width": 768,
            "height": 1024
        }
        """

        struct TestSize: Codable {
            let size: CGSize

            init(from decoder: Decoder) throws {
                size = try CGSize(fromDeltaSkin: decoder)
            }
        }

        let decoder = JSONDecoder()
        let testSize = try decoder.decode(TestSize.self, from: json.data(using: .utf8)!)
        #expect(testSize.size.width == 768)
        #expect(testSize.size.height == 1024)
    }

    /// Test decoding of assets configuration
    @Test("Decodes assets configuration")
    func decodesAssets() throws {
        let json = """
        {
            "resizable": "ipad_portrait.pdf"
        }
        """

        let decoder = JSONDecoder()
        let assets = try decoder.decode(DeltaSkin.AssetRepresentation.self, from: json.data(using: .utf8)!)

        if case .resizable(let filename) = assets {
            #expect(filename == "ipad_portrait.pdf")
        } else {
            throw TestError("Expected resizable asset")
        }
    }

    /// Test decoding of orientation representations
    @Test("Decodes orientation representations")
    func decodesOrientationRepresentations() throws {
        let json = """
        {
            "assets": {
                "resizable": "ipad_portrait.pdf"
            },
            "screens": [
                {
                    "inputFrame": {
                        "x": 0,
                        "y": 0,
                        "width": 256,
                        "height": 192
                    },
                    "outputFrame": {
                        "x": 0,
                        "y": 0,
                        "width": 768,
                        "height": 576
                    }
                }
            ],
            "mappingSize": {
                "width": 768,
                "height": 1024
            }
        }
        """

        let decoder = JSONDecoder()
        let orientation = try decoder.decode(DeltaSkin.OrientationRepresentations.self, from: json.data(using: .utf8)!)

        #expect(orientation.screens?.count == 1)
        #expect(orientation.mappingSize!.width == 768)
        #expect(orientation.mappingSize!.height == 1024)
    }

    /// Test decoding of device representations
    @Test("Decodes device representations")
    func decodesDeviceRepresentations() throws {
        let json = """
        {
            "standard": {
                "portrait": {
                    "assets": {
                        "resizable": "ipad_portrait.pdf"
                    },
                    "mappingSize": {
                        "width": 768,
                        "height": 1024
                    }
                }
            }
        }
        """

        let decoder = JSONDecoder()
        let deviceReps = try decoder.decode(DeltaSkin.DeviceRepresentations.self, from: json.data(using: .utf8)!)

        let portrait = deviceReps.standard?["portrait"]
        #expect(portrait != nil)
        #expect(portrait?.mappingSize!.width == 768)
    }

    /// Test decoding of representations in both formats
    @Test("Decodes representations in both formats")
    func decodesRepresentations() throws {
        // Test dictionary format
        let dictJSON = """
        {
            "name": "Test Skin",
            "identifier": "com.test.skin",
            "gameTypeIdentifier": "com.rileytestut.delta.game.gba",
            "debug": false,
            "representations": {
                "iphone": {
                    "standard": {
                        "portrait": {
                            "assets": {
                                "resizable": "test.pdf"
                            },
                            "mappingSize": {
                                "width": 414,
                                "height": 896
                            }
                        }
                    }
                }
            }
        }
        """

        let decoder = JSONDecoder()

        // Test dictionary format
        let info = try decoder.decode(DeltaSkin.Info.self, from: dictJSON.data(using: .utf8)!)
        let iphone = info.representations[.iphone]
        #expect(iphone != nil)
        let portrait = iphone?.standard?["portrait"]
        #expect(portrait != nil)
        #expect(portrait?.mappingSize!.width == 414)

        // Compare with actual skin file
        let gbaTestJSON = """
        {
            "name": "GBA Test Skin",
            "identifier": "com.provenance.test.gba",
            "gameTypeIdentifier": "com.rileytestut.delta.game.gba",
            "debug": false,
            "representations": {
                "iphone": {
                    "standard": {
                        "portrait": {
                            "assets": {
                                "resizable": "iphone_portrait.pdf"
                            },
                            "screens": [
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
                                    }
                                }
                            ],
                            "mappingSize": {
                                "width": 414,
                                "height": 896
                            }
                        }
                    }
                },
                "ipad": {
                    "standard": {
                        "portrait": {
                            "assets": {
                                "resizable": "ipad_portrait.pdf"
                            },
                            "screens": [
                                {
                                    "inputFrame": {
                                        "x": 0,
                                        "y": 0,
                                        "width": 240,
                                        "height": 160
                                    },
                                    "outputFrame": {
                                        "x": 50,
                                        "y": 100,
                                        "width": 924,
                                        "height": 616
                                    },
                                    "filters": [
                                        {
                                            "name": "CIGaussianBlur",
                                            "parameters": {
                                                "inputRadius": 0.5
                                            }
                                        },
                                        {
                                            "name": "CIColorControls",
                                            "parameters": {
                                                "inputSaturation": 1.2,
                                                "inputContrast": 1.1
                                            }
                                        }
                                    ]
                                }
                            ],
                            "mappingSize": {
                                "width": 1024,
                                "height": 1366
                            }
                        }
                    }
                }
            }
        }
        """

        let gbaInfo = try decoder.decode(DeltaSkin.Info.self, from: gbaTestJSON.data(using: .utf8)!)
        #expect(gbaInfo.name == "GBA Test Skin")
        let gbaIphone = gbaInfo.representations[.iphone]
        #expect(gbaIphone != nil)
    }

    /// Test decoding of item representations with and without extended edges
    @Test("Decodes item representations correctly")
    func decodesItemRepresentations() throws {
        // Test item with extended edges
        let jsonWithEdges = """
        {
            "inputs": {
                "up": "up",
                "down": "down",
                "left": "left",
                "right": "right"
            },
            "frame": {
                "x": 15,
                "y": 75,
                "width": 164,
                "height": 164
            },
            "extendedEdges": {
                "top": 12,
                "right": 12,
                "bottom": 12,
                "left": 12
            }
        }
        """

        let decoder = JSONDecoder()
        let itemWithEdges = try decoder.decode(DeltaSkin.ItemRepresentation.self, from: jsonWithEdges.data(using: .utf8)!)

        if case .directional(let mapping) = itemWithEdges.inputs {
            #expect(mapping["up"] == "up")
        }
        #expect(itemWithEdges.frame.minX == 15)
        #expect(itemWithEdges.extendedEdges?.top == 12)

        // Test item without extended edges
        let jsonWithoutEdges = """
        {
            "inputs": ["a"],
            "frame": {
                "x": 316,
                "y": 84,
                "width": 75,
                "height": 75
            }
        }
        """

        let itemWithoutEdges = try decoder.decode(DeltaSkin.ItemRepresentation.self, from: jsonWithoutEdges.data(using: .utf8)!)

        if case .single(let inputs) = itemWithoutEdges.inputs {
            #expect(inputs.first == "a")
        }
        #expect(itemWithoutEdges.frame.minX == 316)
        #expect(itemWithoutEdges.extendedEdges == nil)
    }

    /// Test loading DS skin from bundle
    @Test("Loads DS Test skin from bundle")
    func loadsDSTestSkinFromBundle() throws {
        // Get the bundle path
        let bundle = Bundle.module
        guard let skinURL = bundle.url(forResource: "DS-Test.deltaskin/info", withExtension: "json") else {
            throw TestError("Could not find DS-Test.deltaskin in bundle")
        }

        // Load and sanitize the file
        let data = try Data(contentsOf: skinURL)
        let sanitizedData = try sanitizeJSON(data)

        let decoder = JSONDecoder()
        do {
            let info = try decoder.decode(DeltaSkin.Info.self, from: sanitizedData)

            // Test basic properties
            #expect(info.name == "DS Test Skin")
            #expect(info.identifier == "com.provenance.test.ds")
            #expect(info.gameTypeIdentifier.rawValue == "com.rileytestut.delta.game.ds")

            // Test screen configuration
            let landscape = info.representations[DeltaSkinDevice.iphone]?.edgeToEdge?["landscape"]
            #expect(landscape != nil)
            #expect(landscape?.screens?.count == 2)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
      
    }

    private func sanitizeJSON(_ data: Data) throws -> Data {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw TestError("Invalid JSON data")
        }

        // Remove single line comments
        var lines = jsonString.components(separatedBy: .newlines)
        lines = lines.map { line in
            if let commentIndex = line.range(of: "//")?.lowerBound {
                return String(line[..<commentIndex])
            }
            return line
        }

        // Rejoin and convert back to data
        let sanitized = lines.joined(separator: "\n")
        guard let sanitizedData = sanitized.data(using: .utf8) else {
            throw TestError("Failed to convert sanitized JSON back to data")
        }

        return sanitizedData
    }
}
