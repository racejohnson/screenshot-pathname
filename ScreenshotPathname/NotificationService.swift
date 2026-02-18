import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        guard AppConfig.shouldNotifyOnCopy else {
            return
        }

        center.getNotificationSettings { [weak self] settings in
            guard let self, settings.authorizationStatus == .notDetermined else {
                return
            }

            self.center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    func notifyCopied(path: String) {
        guard AppConfig.shouldNotifyOnCopy else {
            return
        }

        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.postNotification(path: path)
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    self.postNotification(path: path)
                }
            case .denied:
                return
            @unknown default:
                return
            }
        }
    }

    private func postNotification(path: String) {
        let content = UNMutableNotificationContent()
        content.title = "Copied screenshot path"
        content.body = path

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )

        center.add(request) { error in
            if let error {
                print("Failed to deliver local notification: \(error)")
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
