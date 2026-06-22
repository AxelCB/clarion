import Foundation

public struct ClarionInputResolver {
    private let arguments: [String]
    private let stdinReader: StandardInputReading

    public init(arguments: [String], stdinReader: StandardInputReading) {
        self.arguments = arguments
        self.stdinReader = stdinReader
    }

    public func resolve() -> PreparedNotificationPayload? {
        let flagPayload = CLIArgumentsParser(arguments: arguments).parse()
        let stdinPayload = readStdinPayload()
        let mergedPayload = stdinPayload.merging(overrides: flagPayload)
        return mergedPayload.resolved()
    }

    private func readStdinPayload() -> NotificationPayload {
        guard stdinReader.isInteractive == false else {
            return NotificationPayload()
        }

        guard let data = stdinReader.readAll(), data.isEmpty == false else {
            return NotificationPayload()
        }

        return PayloadParser().parse(data: data) ?? NotificationPayload()
    }
}
