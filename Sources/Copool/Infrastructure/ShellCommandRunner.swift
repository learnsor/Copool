import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WinSDK)
import WinSDK
#endif

struct CommandResult {
    var status: Int32
    var stdout: String
    var stderr: String
}

#if !os(iOS)
enum CommandRunner {
    #if os(Windows)
    private static let systemSearchPaths = [
        "C:\\Windows\\System32",
        "C:\\Windows",
        "C:\\Windows\\System32\\WindowsPowerShell\\v1.0",
    ]
    #else
    private static let systemSearchPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
        "/snap/bin",
    ]
    #endif

    @discardableResult
    static func run(
        _ launchPath: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectory: URL? = nil,
        timeout: TimeInterval? = nil
    ) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        process.environment = runtimeEnvironment(overrides: environment)

        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            let command = "\(launchPath) \(arguments.joined(separator: " "))"
            throw AppError.io(L10n.tr("error.shell.run_failed_format", command, error.localizedDescription))
        }

        if let timeout {
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning {
                if Date() >= deadline {
                    process.terminate()

                    let forceKillDeadline = Date().addingTimeInterval(1.2)
                    while process.isRunning, Date() < forceKillDeadline {
                        Thread.sleep(forTimeInterval: 0.05)
                    }

                    if process.isRunning {
                        #if canImport(Darwin) || canImport(Glibc)
                        _ = kill(process.processIdentifier, SIGKILL)
                        #endif

                        let settleDeadline = Date().addingTimeInterval(0.8)
                        while process.isRunning, Date() < settleDeadline {
                            Thread.sleep(forTimeInterval: 0.05)
                        }
                    }

                    let command = "\(launchPath) \(arguments.joined(separator: " "))"
                    throw AppError.io(
                        L10n.tr("error.shell.timeout_format", String(Int(timeout)), command)
                    )
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
        } else {
            process.waitUntilExit()
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        let result = CommandResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
        return result
    }

    static func runChecked(
        _ launchPath: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectory: URL? = nil,
        timeout: TimeInterval? = nil,
        errorPrefix: String
    ) throws -> CommandResult {
        let result = try run(
            launchPath,
            arguments: arguments,
            environment: environment,
            currentDirectory: currentDirectory,
            timeout: timeout
        )
        guard result.status == 0 else {
            let details = result.stderr.isEmpty ? result.stdout : result.stderr
            throw AppError.io("\(errorPrefix): \(details.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return result
    }

    static func resolveExecutable(_ name: String) -> String? {
        if name.contains("/") || name.contains("\\") {
            return isRunnableFile(atPath: name) ? name : nil
        }

        for base in executableSearchPaths() {
            for candidateName in executableCandidateNames(for: name) {
                let candidate = (base as NSString).appendingPathComponent(candidateName)
                if isRunnableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        #if os(Windows)
        return nil
        #else
        guard let result = try? run("/usr/bin/env", arguments: ["which", name]), result.status == 0 else {
            return nil
        }
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
        #endif
    }

    private static func runtimeEnvironment(overrides: [String: String]?) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let home = environment["HOME"] ?? NSHomeDirectory()
        environment["HOME"] = home

        let existing = environment["PATH"] ?? ""
        let existingParts = existing
            .split(separator: pathListSeparator)
            .map(String.init)
            .filter { !$0.isEmpty }

        var merged: [String] = []
        var seen = Set<String>()
        for part in existingParts {
            if seen.insert(part).inserted {
                merged.append(part)
            }
        }

        for part in systemSearchPaths {
            if seen.insert(part).inserted {
                merged.append(part)
            }
        }

        #if os(Windows)
        let userToolPaths = [
            "\(home)\\.cargo\\bin",
            "\(home)\\AppData\\Local\\Microsoft\\WindowsApps"
        ]
        #else
        let userToolPaths = [
            "\(home)/.cargo/bin",
            "\(home)/.local/bin",
        ]
        #endif
        for part in userToolPaths where FileManager.default.fileExists(atPath: part) {
            if seen.insert(part).inserted {
                merged.append(part)
            }
        }

        environment["PATH"] = merged.joined(separator: String(pathListSeparator))

        if let overrides {
            for (key, value) in overrides {
                environment[key] = value
            }
        }
        return environment
    }

    private static func executableSearchPaths() -> [String] {
        let env = runtimeEnvironment(overrides: nil)
        return (env["PATH"] ?? "")
            .split(separator: pathListSeparator)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static var pathListSeparator: Character {
        #if os(Windows)
        ";"
        #else
        ":"
        #endif
    }

    private static func executableCandidateNames(for name: String) -> [String] {
        #if os(Windows)
        if name.contains(".") {
            return [name]
        }
        let pathExtensions = (ProcessInfo.processInfo.environment["PATHEXT"] ?? ".EXE;.BAT;.CMD;.COM")
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        var candidates = [name]
        for pathExtension in pathExtensions {
            for candidate in [name + pathExtension.lowercased(), name + pathExtension.uppercased()] {
                if seen.insert(candidate.lowercased()).inserted {
                    candidates.append(candidate)
                }
            }
        }
        return candidates
        #else
        return [name]
        #endif
    }

    private static func isRunnableFile(atPath path: String) -> Bool {
        #if os(Windows)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return false
        }
        return true
        #else
        return FileManager.default.isExecutableFile(atPath: path)
        #endif
    }
}
#else
enum CommandRunner {
    @discardableResult
    static func run(
        _ launchPath: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectory: URL? = nil,
        timeout: TimeInterval? = nil
    ) throws -> CommandResult {
        _ = launchPath
        _ = arguments
        _ = environment
        _ = currentDirectory
        _ = timeout
        throw AppError.io(PlatformCapabilities.unsupportedOperationMessage)
    }

    static func runChecked(
        _ launchPath: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectory: URL? = nil,
        timeout: TimeInterval? = nil,
        errorPrefix: String
    ) throws -> CommandResult {
        _ = launchPath
        _ = arguments
        _ = environment
        _ = currentDirectory
        _ = timeout
        throw AppError.io("\(errorPrefix): \(PlatformCapabilities.unsupportedOperationMessage)")
    }

    static func resolveExecutable(_ name: String) -> String? {
        _ = name
        return nil
    }
}
#endif
