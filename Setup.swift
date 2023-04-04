import ProjectDescription

let setup = Setup(
    require: [
        .precondition( 
            .swiftVersion("5.3.2"), 
            .xcodeVersion("12.4", "12D4e"))
    ],
    run: [
        .homebrew(packages: [
            "molten-vk", 
            "swiftformat", 
            "swiftlint", 
            "swiftgen", 
            "swift-doc"
        ]),
        .mint(),
        // .custom(name: "Name", meet: ["./install.sh"], isMet: ["test", "mytool"])
    ]
)
