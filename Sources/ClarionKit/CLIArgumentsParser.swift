import Foundation

public struct CLIArgumentsParser {
    private enum Flag: String, CaseIterable {
        case title = "--title"
        case message = "--message"
        case subtitle = "--subtitle"
        case sound = "--sound"
        case group = "--group"
        case attachment = "--attachment"
    }

    private let arguments: [String]

    public init(arguments: [String]) {
        self.arguments = arguments
    }

    public func parse() -> NotificationPayload {
        var payload = NotificationPayload()
        var index = 1

        while index < arguments.count {
            let token = arguments[index]
            guard let flag = Flag(rawValue: token) else {
                index += 1
                continue
            }

            guard let valueIndex = valueIndex(after: index) else {
                index += 1
                continue
            }

            assign(arguments[valueIndex], to: flag, payload: &payload)
            index = valueIndex + 1
        }

        return payload
    }

    private func valueIndex(after index: Int) -> Int? {
        let nextIndex = index + 1
        guard nextIndex < arguments.count else {
            return nil
        }

        let nextToken = arguments[nextIndex]
        guard Flag(rawValue: nextToken) == nil else {
            return nil
        }

        return nextIndex
    }

    private func assign(_ value: String, to flag: Flag, payload: inout NotificationPayload) {
        switch flag {
        case .title:
            payload.title = value
        case .message:
            payload.message = value
        case .subtitle:
            payload.subtitle = value
        case .sound:
            payload.sound = value
        case .group:
            payload.group = value
        case .attachment:
            payload.attachment = value
        }
    }
}
