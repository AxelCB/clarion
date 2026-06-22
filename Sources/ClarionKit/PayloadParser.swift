import Foundation

public struct PayloadParser {
    public init() {}

    public func parse(data: Data) -> NotificationPayload? {
        guard data.isEmpty == false else {
            return nil
        }

        return try? JSONDecoder().decode(NotificationPayload.self, from: data)
    }
}
