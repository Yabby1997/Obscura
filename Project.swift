import ProjectDescription

let targets: [Target] = [
    Target(
        name: "Obscura",
        platform: .iOS,
        product: .framework,
        bundleId: "com.seunghun.obscura",
        deploymentTarget: .iOS(targetVersion: "16.0", devices: [.iphone]),
        sources: ["Obscura/Sources/**"],
        dependencies: []
    ),
    Target(
        name: "ObscuraDemo",
        platform: .iOS,
        product: .app,
        bundleId: "com.seunghun.obscura.demo",
        deploymentTarget: .iOS(targetVersion: "16.0", devices: [.iphone]),
        infoPlist: .extendingDefault(
            with: [
                "UILaunchStoryboardName": "LaunchScreen",
                "NSCameraUsageDescription": "Camera permission is needed for ObscuraDemo",
            ]
        ),
        sources: ["ObscuraDemo/Sources/**"],
        resources: ["ObscuraDemo/Resources/**"],
        dependencies: [
            .target(name: "Obscura")
        ],
        settings: .settings(
            base: ["DEVELOPMENT_TEAM": "5HZQ3M82FA"],
            configurations: [],
            defaultSettings: .recommended
        )
    )
]

let project = Project(
    name: "Obscura",
    organizationName: "seunghun",
    targets: targets
)
