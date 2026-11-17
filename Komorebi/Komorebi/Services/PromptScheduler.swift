import Foundation
import Observation
import UserNotifications
import UIKit

/// Schedules the evening and night activity prompts as real local notifications.
/// Prompts shown as a Lock Screen widget need no notification; the widget changes on its own schedule.
@Observable
final class PromptScheduler {
    static let shared = PromptScheduler()

    enum Permission { case unknown, notDetermined, allowed, denied }
    private(set) var permission: Permission = .unknown

    private let center = UNUserNotificationCenter.current()
    private let prefix = "komorebi.prompt."

    private init() { refreshAuthorizationStatus() }

    func refreshAuthorizationStatus() {
        center.getNotificationSettings { settings in
            let p: Permission
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: p = .allowed
            case .denied: p = .denied
            case .notDetermined: p = .notDetermined
            @unknown default: p = .unknown
            }
            DispatchQueue.main.async { self.permission = p }
        }
    }

    /// Asks for permission the first time a notification prompt is turned on.
    func requestPermission(then done: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.permission = granted ? .allowed : .denied
                done?(granted)
                let store = AppStore.shared
                self.apply(evening: store.state.evening, night: store.state.night)
            }
        }
    }

    func apply(evening: PromptSchedule, night: PromptSchedule) {
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(self.prefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)

            if evening.isOn && evening.style == .notification {
                for day in evening.activeWeekdays {
                    self.add(id: "evening.\(day)", weekday: day, minutes: evening.startMinutes,
                             title: "A little less to carry",
                             body: "Tonight’s suggestion: Lantern release, about 2 minutes. Or tap to see what else is waiting.",
                             link: KomorebiLink.tonight, passive: false)
                }
            }
            if night.isOn && night.style == .notification {
                for day in night.activeWeekdays {
                    // A window that starts after midnight belongs to the next calendar day.
                    let fireDay = night.startMinutes < 12 * 60 ? (day % 7) + 1 : day
                    self.add(id: "night.\(day)", weekday: fireDay, minutes: night.startMinutes,
                             title: "Still awake?",
                             body: "A slow sand garden can help you drift back to sleep. No need to reply.",
                             link: KomorebiLink.garden, passive: true)
                }
            }
        }
    }

    private func add(id: String, weekday: Int, minutes: Int, title: String, body: String, link: URL, passive: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = ["link": link.absoluteString]
        content.threadIdentifier = "komorebi.prompts"
        // Passive prompts never light the screen or make a sound; they wait for the person to look.
        content.interruptionLevel = passive ? .passive : .active
        content.sound = nil

        var when = DateComponents()
        when.weekday = weekday
        when.hour = minutes / 60
        when.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        center.add(UNNotificationRequest(identifier: prefix + id, content: content, trigger: trigger))
    }

    /// Sends one prompt in a few seconds so people can see what it looks like.
    func sendPreview(night: Bool) {
        let content = UNMutableNotificationContent()
        content.title = night ? "Still awake?" : "A little less to carry"
        content.body = night ? "A slow sand garden can help you drift back to sleep. No need to reply."
                             : "Tonight’s suggestion: Lantern release, about 2 minutes."
        content.userInfo = ["link": (night ? KomorebiLink.garden : KomorebiLink.tonight).absoluteString]
        content.interruptionLevel = .active
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        center.add(UNNotificationRequest(identifier: prefix + "preview", content: content, trigger: trigger))
    }

    /// Reminds monthly-kit subscribers three days before the next box ships.
    func scheduleKitReminders(for orders: [KitOrder]) {
        let ids = orders.map { "komorebi.kit.\($0.id.uuidString)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        for order in orders {
            guard let ship = order.nextShipDate,
                  let remind = Calendar.current.date(byAdding: .day, value: -3, to: ship), remind > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Your next Komorebi kit ships in 3 days"
            content.body = "$18.00 on \(ship.formatted(date: .abbreviated, time: .omitted)). Skip or cancel anytime in Profile."
            content.userInfo = ["link": KomorebiLink.kits.absoluteString]
            content.interruptionLevel = .passive
            var parts = Calendar.current.dateComponents([.year, .month, .day], from: remind)
            parts.hour = 18
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            center.add(UNNotificationRequest(identifier: "komorebi.kit.\(order.id.uuidString)", content: content, trigger: trigger))
        }
    }

    func openSystemSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
