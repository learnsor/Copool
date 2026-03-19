// swift-tools-version: 6.0
import PackageDescription

let resources: [Resource] = [
    .process("Resources")
]

#if os(Linux) || os(Windows)
let portableExcludes = [
    "App",
    "Copool.icon",
    "CopoolApp.swift",
    "Features",
    "UI",
    "Behavior/ProxyControlBridge.swift",
    "Behavior/ProxyCoordinator.swift",
    "Behavior/UpdateCoordinator.swift",
    "Infrastructure/ChatGPTBaseOriginResolver.swift",
    "Infrastructure/CloudKitAccountsSyncService.swift",
    "Infrastructure/CloudKitProxyControlSyncService.swift",
    "Infrastructure/CloudflaredService.swift",
    "Infrastructure/CodexCLIService.swift",
    "Infrastructure/DefaultUsageService.swift",
    "Infrastructure/DefaultWorkspaceMetadataService.swift",
    "Infrastructure/EditorAppService.swift",
    "Infrastructure/GitHubUpdateService.swift",
    "Infrastructure/LaunchAtStartupService.swift",
    "Infrastructure/OpenAIChatGPTOAuthLoginService.swift",
    "Infrastructure/OpencodeAuthSyncService.swift",
    "Infrastructure/RemoteProxyService.swift",
    "Infrastructure/RepositoryLocator.swift",
    "Infrastructure/SimpleHTTPServer.swift",
    "Infrastructure/SwiftNativeProxyRuntimeService.swift"
]
let portableSources = [
    "Behavior/AccountRanking.swift",
    "Behavior/AccountsCoordinator.swift",
    "Behavior/SettingsCoordinator.swift",
    "Behavior/UsageWindowSelector.swift",
    "Domain",
    "Infrastructure/AuthFileRepository.swift",
    "Infrastructure/FileSystemPaths.swift",
    "Infrastructure/ShellCommandRunner.swift",
    "Infrastructure/StoreFileRepository.swift",
    "Infrastructure/SystemDateProvider.swift",
    "Layout",
    "LinuxMain.swift"
]
let copoolTarget: Target = .executableTarget(
    name: "Copool",
    path: "Sources/Copool",
    exclude: portableExcludes,
    sources: portableSources,
    resources: resources
)
#else
let sourceExcludes = [
    "LinuxMain.swift"
]
let copoolTarget: Target = .executableTarget(
    name: "Copool",
    path: "Sources/Copool",
    exclude: sourceExcludes,
    resources: resources
)
#endif

let package = Package(
    name: "Copool",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Copool", targets: ["Copool"])
    ],
    targets: [
        copoolTarget,
        .testTarget(
            name: "CopoolTests",
            dependencies: ["Copool"],
            path: "Tests/CopoolTests"
        )
    ]
)
