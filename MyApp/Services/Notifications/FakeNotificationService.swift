import Foundation
import UserNotifications

/// Real local notifications, fake "backend push". The plan calls for a Supabase
/// Edge Function that geo-selects nearby users and sends APNs on Clean-Up insert —
/// that needs a server and real devices. This uses the plan's own documented demo
/// fallback: a local notification, scheduled a couple of seconds out to feel like
/// "someone nearby just told you about this".
struct FakeNotificationService: NotificationService {
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func notifyNearby(of cleanUp: CleanUp) async {
        let content = UNMutableNotificationContent()
        content.title = "New Clean-Up nearby"
        content.body = "\(cleanUp.hostName) spotted \(cleanUp.wasteTypes.first?.label.lowercased() ?? "waste") near you — \(cleanUp.title)."
        content.sound = .default
        content.userInfo = ["cleanUpId": cleanUp.id.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "nearby-\(cleanUp.id.uuidString)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func scheduleReminder(for cleanUp: CleanUp) async {
        guard let startsAt = cleanUp.startsAt else { return }
        let fireDate = startsAt.addingTimeInterval(-15 * 60)
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Starting soon: \(cleanUp.title)"
        content.body = "Grab your gear — this Clean-Up starts in 15 minutes."
        content.sound = .default

        let interval = fireDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(interval, 1), repeats: false)
        let request = UNNotificationRequest(identifier: "reminder-\(cleanUp.id.uuidString)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
