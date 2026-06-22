import ClarionKit
import Foundation
import Testing

private struct ProcessResult {
    let status: Int32
    let stdout: String
    let stderr: String
}

@Test
func clarionExitsSilentlyWithNoInput() throws {
    let result = try runProcess(
        executableURL: try builtExecutableURL(named: "clarion"),
        arguments: []
    )

    #expect(result.status == 0)
    #expect(result.stdout.isEmpty)
    #expect(result.stderr.isEmpty)
}

@Test
func clarionExitsSilentlyWithMalformedStdinAndNoFlags() throws {
    let result = try runProcess(
        executableURL: try builtExecutableURL(named: "clarion"),
        arguments: [],
        standardInput: "{invalid"
    )

    #expect(result.status == 0)
    #expect(result.stdout.isEmpty)
    #expect(result.stderr.isEmpty)
}

@Test
func clarionProcessRespectsFlagOverridesOverStdin() throws {
    let captureURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).json", isDirectory: false)

    let result = try runProcess(
        executableURL: try builtExecutableURL(named: "clarion"),
        arguments: ["--title", "Override", "--message", "Flags win"],
        environment: ["CLARION_CAPTURE_PAYLOAD_FILE": captureURL.path],
        standardInput: #"{"title":"ignored","message":"also ignored","subtitle":"from stdin"}"#
    )

    let capturedPayload = try JSONDecoder().decode(
        PreparedNotificationPayload.self,
        from: Data(contentsOf: captureURL)
    )

    #expect(result.status == 0)
    #expect(result.stdout.isEmpty)
    #expect(result.stderr.isEmpty)
    #expect(capturedPayload.title == "Override")
    #expect(capturedPayload.message == "Flags win")
    #expect(capturedPayload.subtitle == "from stdin")
}

@Test
func packageToolBuildsBundleBinary() throws {
    let packageToolURL = try builtExecutableURL(named: "clarion-package")
    let bundleBinaryURL = packageRootURL()
        .appendingPathComponent("Clarion.app/Contents/MacOS/clarion", isDirectory: false)

    let result = try runProcess(
        executableURL: packageToolURL,
        arguments: ["bundle"],
        environment: ["CLARION_PACKAGE_BINARY_PATH": try builtExecutableURL(named: "clarion").path],
        currentDirectoryURL: packageRootURL()
    )

    #expect(result.status == 0)
    #expect(FileManager.default.fileExists(atPath: bundleBinaryURL.path))
}

private func runProcess(
    executableURL: URL,
    arguments: [String],
    environment: [String: String] = [:],
    currentDirectoryURL: URL? = nil,
    standardInput: String? = nil
) throws -> ProcessResult {
    let process = Process()
    let stdin = Pipe()
    let stdoutURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: false)
    let stderrURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: false)
    FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
    FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
    let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
    let stderrHandle = try FileHandle(forWritingTo: stderrURL)

    process.executableURL = executableURL
    process.arguments = arguments
    process.currentDirectoryURL = currentDirectoryURL
    process.standardOutput = stdoutHandle
    process.standardError = stderrHandle
    process.standardInput = stdin
    process.environment = processEnvironment(overrides: environment)

    try process.run()

    if let standardInput {
        stdin.fileHandleForWriting.write(Data(standardInput.utf8))
    }
    try? stdin.fileHandleForWriting.close()

    process.waitUntilExit()

    try stdoutHandle.close()
    try stderrHandle.close()

    let stdout = try String(decoding: Data(contentsOf: stdoutURL), as: UTF8.self)
    let stderr = try String(decoding: Data(contentsOf: stderrURL), as: UTF8.self)
    try? FileManager.default.removeItem(at: stdoutURL)
    try? FileManager.default.removeItem(at: stderrURL)

    return ProcessResult(
        status: process.terminationStatus,
        stdout: stdout,
        stderr: stderr
    )
}

private func builtExecutableURL(named name: String) throws -> URL {
    let buildRoot = packageRootURL().appendingPathComponent(".build", isDirectory: true)
    let enumerator = FileManager.default.enumerator(
        at: buildRoot,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    )

    while let next = enumerator?.nextObject() as? URL {
        guard next.lastPathComponent == name,
              next.path.contains("/debug/"),
              next.path.contains(".dSYM/") == false
        else {
            continue
        }

        return next
    }

    throw SmokeTestError.executableNotFound(name)
}

private func packageRootURL() -> URL {
    URL(fileURLWithPath: #filePath, isDirectory: false)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func processEnvironment(overrides: [String: String]) -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    let packageRoot = packageRootURL()
    environment["SWIFT_MODULE_CACHE_PATH"] = packageRoot.appendingPathComponent(".build/swift-module-cache").path
    environment["CLANG_MODULE_CACHE_PATH"] = packageRoot.appendingPathComponent(".build/clang-module-cache").path

    for (key, value) in overrides {
        environment[key] = value
    }

    return environment
}

private enum SmokeTestError: Error {
    case executableNotFound(String)
}
