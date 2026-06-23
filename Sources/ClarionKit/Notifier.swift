// Copyright (c) 2026 Axel Collard Bovy. SPDX-License-Identifier: MIT

import Foundation
@preconcurrency import UserNotifications

public protocol Notifying: Sendable {
    func post(_ payload: PreparedNotificationPayload)
}

public struct Notifier: Notifying, Sendable {
    private let notificationCenter: NotificationCenterClient
    private let requestBuilder: NotificationRequestBuilding

    public init(
        notificationCenter: NotificationCenterClient = SystemNotificationCenterClient(),
        requestBuilder: NotificationRequestBuilding = NotificationRequestBuilder()
    ) {
        self.notificationCenter = notificationCenter
        self.requestBuilder = requestBuilder
    }

    public func post(_ payload: PreparedNotificationPayload) {
        let semaphore = DispatchSemaphore(value: 0)
        let notificationCenter = notificationCenter
        let requestBuilder = requestBuilder

        notificationCenter.requestAuthorization { isGranted, _ in
            guard isGranted else {
                semaphore.signal()
                return
            }

            let request = requestBuilder.makeRequest(from: payload)
            notificationCenter.add(request) { _ in
                semaphore.signal()
            }
        }

        semaphore.wait()
    }
}

public protocol NotificationRequestBuilding: Sendable {
    func makeRequest(from payload: PreparedNotificationPayload) -> NotificationRequestDescriptor
}

public struct NotificationRequestBuilder: NotificationRequestBuilding, Sendable {
    public init() {}

    public func makeRequest(from payload: PreparedNotificationPayload) -> NotificationRequestDescriptor {
        let normalizedGroup = payload.group.flatMap { $0.isEmpty ? nil : $0 }
        let requestIdentifier = normalizedGroup ?? UUID().uuidString

        return NotificationRequestDescriptor(
            identifier: requestIdentifier,
            title: payload.title,
            body: payload.message,
            subtitle: payload.subtitle,
            threadIdentifier: normalizedGroup,
            sound: NotificationSoundDescriptor(rawValue: payload.sound),
            attachmentURL: resolvedAttachmentURL(from: payload.attachment)
        )
    }

    private func resolvedAttachmentURL(from attachmentPath: String?) -> URL? {
        guard let attachmentPath,
              attachmentPath.isEmpty == false,
              attachmentPath.hasPrefix("/")
        else {
            return nil
        }

        let url = URL(fileURLWithPath: attachmentPath, isDirectory: false)
        let allowedExtensions = ["png", "jpg", "jpeg"]
        guard allowedExtensions.contains(url.pathExtension.lowercased()),
              FileManager.default.fileExists(atPath: url.path)
        else {
            return nil
        }

        return url
    }
}

public struct NotificationRequestDescriptor: Equatable, Sendable {
    public let identifier: String
    public let title: String
    public let body: String
    public let subtitle: String?
    public let threadIdentifier: String?
    public let sound: NotificationSoundDescriptor
    public let attachmentURL: URL?

    public init(
        identifier: String,
        title: String,
        body: String,
        subtitle: String?,
        threadIdentifier: String?,
        sound: NotificationSoundDescriptor,
        attachmentURL: URL?
    ) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.threadIdentifier = threadIdentifier
        self.sound = sound
        self.attachmentURL = attachmentURL
    }
}

public enum NotificationSoundDescriptor: Equatable, Sendable {
    case `default`
    case named(String)

    public init(rawValue: String?) {
        guard let rawValue, rawValue.isEmpty == false, rawValue.caseInsensitiveCompare("default") != .orderedSame else {
            self = .default
            return
        }

        self = .named(rawValue)
    }
}

public protocol NotificationCenterClient: Sendable {
    func requestAuthorization(completion: @escaping @Sendable (Bool, Error?) -> Void)
    func add(_ request: NotificationRequestDescriptor, completion: @escaping @Sendable (Error?) -> Void)
}

public struct SystemNotificationCenterClient: NotificationCenterClient, @unchecked Sendable {
    private let userNotificationCenter: UserNotificationCentering

    public init(userNotificationCenter: UserNotificationCentering = UNUserNotificationCenter.current()) {
        self.userNotificationCenter = userNotificationCenter
    }

    public func requestAuthorization(completion: @escaping @Sendable (Bool, Error?) -> Void) {
        userNotificationCenter.requestAuthorization(options: [.alert, .sound], completionHandler: completion)
    }

    public func add(_ request: NotificationRequestDescriptor, completion: @escaping @Sendable (Error?) -> Void) {
        userNotificationCenter.add(makeSystemRequest(from: request), withCompletionHandler: completion)
    }

    private func makeSystemRequest(from request: NotificationRequestDescriptor) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.subtitle = request.subtitle ?? ""
        content.sound = makeSound(from: request.sound)

        if let threadIdentifier = request.threadIdentifier {
            content.threadIdentifier = threadIdentifier
        }

        if let attachment = makeAttachment(from: request.attachmentURL) {
            content.attachments = [attachment]
        }

        return UNNotificationRequest(identifier: request.identifier, content: content, trigger: nil)
    }

    private func makeSound(from sound: NotificationSoundDescriptor) -> UNNotificationSound {
        switch sound {
        case .default:
            return .default
        case .named(let name):
            return UNNotificationSound(named: UNNotificationSoundName(name))
        }
    }

    private func makeAttachment(from url: URL?) -> UNNotificationAttachment? {
        guard let url else {
            return nil
        }

        return try? UNNotificationAttachment(identifier: url.lastPathComponent, url: url)
    }
}

public protocol UserNotificationCentering {
    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, Error?) -> Void
    )

    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?
    )
}

extension UNUserNotificationCenter: UserNotificationCentering {}
