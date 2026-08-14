import Foundation
import UserNotifications

enum NotificationScheduler {
    private static let identifier = "fastabs-daily-reminder"

    static func requestAndSchedule(hour: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return false }
            center.removePendingNotificationRequests(withIdentifiers: [identifier])

            let content = UNMutableNotificationContent()
            content.title = "Votre programme FastAbs est prêt"
            content.body = "Quelques minutes suffisent pour entretenir votre série."
            content.sound = .default

            var date = DateComponents()
            date.hour = hour
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            return true
        } catch {
            return false
        }
    }

    static func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

