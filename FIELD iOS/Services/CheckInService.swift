import Foundation
import UserNotifications

@MainActor
final class CheckInService: ObservableObject {
    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined
    @Published private(set) var nextDue: Date?

    func refreshAuthorization() async {
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestAuthorization() async {
        do { _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) }
        catch { }
        await refreshAuthorization()
    }

    func schedule(plan: TripPlan) async {
        await requestAuthorization()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["field.checkin"])
        guard plan.checkInIntervalMinutes > 0 else { nextDue = nil; return }
        let due = Date().addingTimeInterval(Double(plan.checkInIntervalMinutes) * 60)
        nextDue = due
        let content = UNMutableNotificationContent()
        content.title = "FIELD / OS Check-in"
        content.body = "Scheduled field check-in is due. Confirm your status and communications link."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, due.timeIntervalSinceNow), repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "field.checkin", content: content, trigger: trigger))
    }

    func cancel() {
        nextDue = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["field.checkin"])
    }
}
