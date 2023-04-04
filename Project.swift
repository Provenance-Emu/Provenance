import ProjectDescription

let packages: [Project.Dependency] = [
    "PVSupport",
    "PVLibrary",
    "PVLogging",
    ].map { .package(product: $0) }
    
let project = Project(
    name: "",
    organizationName: "Provenance.io",
    targets: [
        Target(
            name: "Provenance",
            platform: .iOS,
            product: .app,
            bundleId: "com.provenance-emu.provenance",
            infoPlist: "Info.plist",
            sources: ["ProvenanceApp/Sources/Provenance/**"],
            resources: ["ProvenanceApp/Sources/Provenance/Resources/**"],
            headers: .headers(
                public: [],
                private: [],
                project: []
            ),
			entitlements: "ProvenanceApp/Sources/Provenance/Resources/Provenance.entitlements",
            dependencies: [
				.target(name: "SideWidget"),
            ] + packages,
			settings: .settings(configurations: [
				.debug(name: "Debug", xcconfig: "ProvenanceApp/Configurations/Provenance-Debug.xcconfig"),
				.release(name: "Release", xcconfig: "ProvenanceApp/Configurations/Provenance-Release.xcconfig"),
			])
        ),

          Target(
            name: "SpotlightExtension",
            platform: .iOS,
            product: .appExtension,
            bundleId: "com.provenance-emu.provenance.spotlight",
            infoPlist: .extendingDefault(with: [
                "ALTAppGroups": [
                    "group.com.provenance-emu.provenance",
                    "group.$(APP_GROUP_IDENTIFIER)",
                    ],
                "CFBundleDisplayName": "$(PRODUCT_NAME)",
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
                    "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).NotificationService"
                ]
            ]),
			sources: ["ProvenanceApp/Sources/SideWidget/**"],
			entitlements: "ProvenanceApp/Sources/SideWidget/Resources/SideWidgetExtension.entitlements",
            dependencies: [
                .package(product: "Shared"),
                .package(product: "AltStoreCore")
            ]
        ),
		Target(
			name: "Provenance",
			platform: .tvOS,
			product: .app,
			bundleId: "com.provenance-emu.provenance",
			infoPlist: "Info.plist",
			sources: ["ProvenanceApp/Sources/ProvenanceTV/**"],
			dependencies: [
				.target(name: "TopShelfExtension"),
			]
		),
		Target(
			name: "TopShelfExtension",
			platform: .tvOS,
			product: .tvTopShelfExtension,
			bundleId: "com.provenance-emu.provenance.TopShelfExtension",
			infoPlist: .extendingDefault(with: [
				"CFBundleDisplayName": "$(PRODUCT_NAME)",
				"NSExtension": [
					"NSExtensionPointIdentifier": "com.apple.tv-top-shelf",
					"NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).ContentProvider",
				],
			]),
			sources: "ProvenanceApp/Sources/TopShelfExtension/**",
			dependencies: [
			]
		),
    ]
)
