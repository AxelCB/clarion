import Foundation

public struct NotificationPayload: Codable, Equatable, Sendable {
    public var title: String?
    public var message: String?
    public var subtitle: String?
    public var sound: String?
    public var group: String?
    public var attachment: String?

    public init(
        title: String? = nil,
        message: String? = nil,
        subtitle: String? = nil,
        sound: String? = nil,
        group: String? = nil,
        attachment: String? = nil
    ) {
        self.title = title
        self.message = message
        self.subtitle = subtitle
        self.sound = sound
        self.group = group
        self.attachment = attachment
    }

    public func merging(overrides: NotificationPayload) -> NotificationPayload {
        NotificationPayload(
            title: overrides.title ?? title,
            message: overrides.message ?? message,
            subtitle: overrides.subtitle ?? subtitle,
            sound: overrides.sound ?? sound,
            group: overrides.group ?? group,
            attachment: overrides.attachment ?? attachment
        )
    }

    public func resolved() -> PreparedNotificationPayload? {
        guard let title, let message else {
            return nil
        }

        return PreparedNotificationPayload(
            title: title,
            message: message,
            subtitle: subtitle,
            sound: sound,
            group: group,
            attachment: attachment
        )
    }
}

public struct PreparedNotificationPayload: Codable, Equatable, Sendable {
    public let title: String
    public let message: String
    public let subtitle: String?
    public let sound: String?
    public let group: String?
    public let attachment: String?

    public init(
        title: String,
        message: String,
        subtitle: String?,
        sound: String?,
        group: String?,
        attachment: String?
    ) {
        self.title = title
        self.message = message
        self.subtitle = subtitle
        self.sound = sound
        self.group = group
        self.attachment = attachment
    }
}
