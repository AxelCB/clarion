import Foundation

public enum ClarionCommand {
    public static func run(
        arguments: [String] = CommandLine.arguments,
        stdinReader: StandardInputReading = SystemStandardInputReader(),
        notifier: Notifying? = nil
    ) -> Int32 {
        guard let payload = ClarionInputResolver(arguments: arguments, stdinReader: stdinReader).resolve() else {
            return 0
        }

#if DEBUG
        if let capturePath = ProcessInfo.processInfo.environment["CLARION_CAPTURE_PAYLOAD_FILE"] {
            try? DebugPayloadCapture.write(payload, to: URL(fileURLWithPath: capturePath, isDirectory: false))
            return 0
        }
#endif

        let resolvedNotifier = notifier ?? Notifier()
        resolvedNotifier.post(payload)
        return 0
    }
}
