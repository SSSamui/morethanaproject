// Notifications: the iPhone version of the messages on the page and of
// Pork's window that stays on top while the break is over.

import Foundation
import UserNotifications

enum Alerts {
    static let goalCategory = "pork.goal"
    static let overCategory = "pork.over"
    static let takeBreakAction = "pork.takeBreak"
    static let letOutAction = "pork.letOut"

    private static let reminders = 12 // "still scratching" reminders, 3 min apart
    private static var ids: [String] {
        ["pork.goal", "pork.over"] + (0...reminders).map { "pork.scratch.\($0)" }
    }

    static func registerCategories() {
        let takeBreak = UNNotificationAction(identifier: takeBreakAction, title: "Take a break 🦴", options: [])
        let letOut = UNNotificationAction(identifier: letOutAction, title: "🐾 End the fun — let Pork out", options: [])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: goalCategory, actions: [takeBreak], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: overCategory, actions: [letOut], intentIdentifiers: [], options: [])
        ])
    }

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Plan the reminders for the current state (and cancel the old ones).
    static func schedule(_ s: PorkState) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard !s.paused else { return }
        let now = Date()

        switch s.phase {
        case .focus:
            guard let goal = s.endsAt, goal > now else { return }
            add("pork.goal", at: goal,
                title: "Focus goal reached! 🦴",
                body: "Pork earned a treat. Keep focusing for a bonus treat every \(s.settings.bonusEveryMin) min, or take your break.",
                category: goalCategory, sound: .default)
        case .break, .overtime:
            guard let over = s.phase == .break ? s.endsAt : s.overtimeFrom else { return }
            let scratch: UNNotificationSound = s.settings.sound
                ? UNNotificationSound(named: UNNotificationSoundName("scratch.wav"))
                : .default
            if over > now {
                add("pork.over", at: over,
                    title: "Break is over! Can we go out? 🥺",
                    body: "Pork is pacing by the door. Extra break time gets added to your next focus.",
                    category: overCategory, sound: .default)
            }
            for k in 0...reminders {
                let late = paceSeconds + Double(k) * 180
                let at = over.addingTimeInterval(late)
                guard at > now else { continue }
                add("pork.scratch.\(k)", at: at,
                    title: k == 0 ? "Woof! Let me out! 🐾" : "Pork is still scratching the door 🐾",
                    body: "Your break is \(Int(late / 60)) min over. That time gets added to your next focus.",
                    category: overCategory, sound: scratch)
            }
        case .idle:
            break
        }
    }

    /// Tell what just happened (when it happened outside the app).
    static func announce(_ cmd: PorkCommand, _ s: PorkState) {
        let title: String, body: String
        switch cmd {
        case .takeBreak where s.phase == .break:
            let items = s.lastReward?.items.joined() ?? "🦴"
            let end = s.endsAt.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short) } ?? ""
            title = "Break time! Pork got \(items)"
            body = "Pork is waiting by the door. Your break ends at \(end)."
        case .release where s.phase == .focus:
            title = "Pork is out! 🐾"
            body = s.carry > 0
                ? "Next focus: \(PorkClock.text(s.target)) (\(PorkClock.text(TimeInterval(s.settings.focusMin * 60))) + \(PorkClock.text(s.carry)) late)."
                : "Next focus: \(PorkClock.text(s.target))."
        default:
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "pork.now", content: content, trigger: nil))
    }

    private static func add(_ id: String, at date: Date, title: String, body: String,
                            category: String, sound: UNNotificationSound) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.categoryIdentifier = category
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
