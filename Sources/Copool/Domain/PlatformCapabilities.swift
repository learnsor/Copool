import Foundation

enum RuntimePlatform: Equatable {
    case macOS
    case iOS
    case linux
    case windows
}

enum PlatformCapabilities {
    #if os(macOS)
    static let currentPlatform: RuntimePlatform = .macOS
    #elseif os(Linux)
    static let currentPlatform: RuntimePlatform = .linux
    #elseif os(Windows)
    static let currentPlatform: RuntimePlatform = .windows
    #else
    static let currentPlatform: RuntimePlatform = .iOS
    #endif

    static var supportsMenuBarScene: Bool { currentPlatform == .macOS }
    static var supportsLaunchAtStartup: Bool { currentPlatform == .macOS }
    static var supportsShellCommands: Bool { currentPlatform != .iOS }
    static var supportsCodexCLI: Bool { currentPlatform == .macOS }
    static var supportsCloudflared: Bool { currentPlatform == .macOS }
    static var supportsRemoteShellManagement: Bool { currentPlatform == .macOS }

    static let unsupportedOperationMessage = "This operation is unavailable on this platform. Run it from Copool on macOS or move it to a backend service."
}
