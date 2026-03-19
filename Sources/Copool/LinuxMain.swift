import Foundation

@main
enum CopoolLinuxMain {
    static func main() {
        print(
            """
            Copool core package is available on this platform.
            The SwiftUI app remains macOS/iOS-only, but you can now use SwiftPM to build, run, and test the portable core on Linux and Windows.
            """
        )
    }
}
