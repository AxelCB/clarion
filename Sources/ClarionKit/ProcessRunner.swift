import Foundation

public protocol ProcessRunning {
    @discardableResult
    func run(_ launchPath: String, arguments: [String], currentDirectoryURL: URL?) throws -> String
}

public struct ShellProcessRunner: ProcessRunning {
    public init() {}

    @discardableResult
    public func run(_ launchPath: String, arguments: [String], currentDirectoryURL: URL?) throws -> String {
        let process = Process()
        let workingDirectoryURL = currentDirectoryURL
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let swiftModuleCacheURL = workingDirectoryURL
            .appendingPathComponent(".build/swift-module-cache", isDirectory: true)
        let clangModuleCacheURL = workingDirectoryURL
            .appendingPathComponent(".build/clang-module-cache", isDirectory: true)
        let stdoutURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
        let stderrURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)

        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle
        process.environment = configuredEnvironment(
            base: ProcessInfo.processInfo.environment,
            swiftModuleCacheURL: swiftModuleCacheURL,
            clangModuleCacheURL: clangModuleCacheURL
        )

        try FileManager.default.createDirectory(at: swiftModuleCacheURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: clangModuleCacheURL, withIntermediateDirectories: true)

        try process.run()
        process.waitUntilExit()

        try stdoutHandle.close()
        try stderrHandle.close()

        let outputData = try Data(contentsOf: stdoutURL)
        let errorData = try Data(contentsOf: stderrURL)
        let output = String(decoding: outputData, as: UTF8.self)
        let error = String(decoding: errorData, as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw ProcessRunnerError.commandFailed(
                launchPath: launchPath,
                arguments: arguments,
                status: process.terminationStatus,
                stderr: error
            )
        }

        try? FileManager.default.removeItem(at: stdoutURL)
        try? FileManager.default.removeItem(at: stderrURL)

        return output.isEmpty ? error : output
    }

    private func configuredEnvironment(
        base: [String: String],
        swiftModuleCacheURL: URL,
        clangModuleCacheURL: URL
    ) -> [String: String] {
        var environment = base
        environment["SWIFT_MODULE_CACHE_PATH"] = swiftModuleCacheURL.path
        environment["CLANG_MODULE_CACHE_PATH"] = clangModuleCacheURL.path
        return environment
    }
}

public enum ProcessRunnerError: Error {
    case commandFailed(launchPath: String, arguments: [String], status: Int32, stderr: String)
}
