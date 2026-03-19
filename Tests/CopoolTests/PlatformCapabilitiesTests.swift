import XCTest
@testable import Copool

final class PlatformCapabilitiesTests: XCTestCase {
    func testUnsupportedOperationMessageIsPlatformNeutral() {
        XCTAssertFalse(PlatformCapabilities.unsupportedOperationMessage.contains("iOS"))
    }

    #if os(Linux)
    func testLinuxBuildReportsLinuxRuntimePlatform() {
        XCTAssertEqual(PlatformCapabilities.currentPlatform, .linux)
        XCTAssertTrue(PlatformCapabilities.supportsShellCommands)
        XCTAssertFalse(PlatformCapabilities.supportsCloudflared)
    }
    #endif

    #if os(Windows)
    func testWindowsBuildReportsWindowsRuntimePlatform() {
        XCTAssertEqual(PlatformCapabilities.currentPlatform, .windows)
        XCTAssertTrue(PlatformCapabilities.supportsShellCommands)
        XCTAssertFalse(PlatformCapabilities.supportsCloudflared)
    }
    #endif
}
