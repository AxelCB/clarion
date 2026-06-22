import Foundation

public enum ClarionCommand {
    public static func run(
        arguments: [String] = CommandLine.arguments,
        stdinReader: StandardInputReading = SystemStandardInputReader(),
        notifier: Notifying = Notifier()
    ) -> Int32 {
        guard let payload = ClarionInputResolver(arguments: arguments, stdinReader: stdinReader).resolve() else {
            return 0
        }

        notifier.post(payload)
        return 0
    }
}
