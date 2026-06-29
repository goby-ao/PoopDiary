import Foundation
import UserNotifications

enum NotificationManager {
    static let dailyIdentifier = "poopdiary.dailyCheckIn"

    static func scheduleDailyReminder(hour: Int, minute: Int) async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { return }

        center.removePendingNotificationRequests(withIdentifiers: [dailyIdentifier])

        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.poopDiary
        dateComponents.hour = hour
        dateComponents.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "便便日记"
        content.body = "今天的小星星等你来点亮～"
        content.sound = .default

        // 本地每日提醒，不联网、不依赖后端。
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: dailyIdentifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyIdentifier])
    }
}
