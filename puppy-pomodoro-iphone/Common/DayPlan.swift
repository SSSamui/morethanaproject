// Today's promise to Pork: how much play time (apps and websites that aren't
// focus apps) and when we go to sleep. Made every morning after 8 am.
// Used by the app, the widgets and the Screen Time extensions.

import Foundation

struct DayPlan: Codable, Equatable {
    var day: String        // "2026-10-20"
    var promiseMin: Int    // minutes of play time promised
    var bedtime: Int       // minutes after midnight (0 = 12:00 am)
    var madeAt: Date
}

/// The App Group shared by the app and its extensions.
enum PorkGroup {
    static let id = (Bundle.main.object(forInfoDictionaryKey: "PorkAppGroup") as? String)
        ?? "group.com.sssamui.puppypomodoro"
    static var defaults: UserDefaults { UserDefaults(suiteName: id) ?? .standard }
}

enum DayPlans {
    /// The morning question comes after this hour.
    static let wakeHour = 8
    private static let key = "dayPlans"

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func all(_ defaults: UserDefaults = PorkGroup.defaults) -> [DayPlan] {
        guard let data = defaults.data(forKey: key),
              let plans = try? JSONDecoder().decode([DayPlan].self, from: data) else { return [] }
        return plans
    }

    static func plan(for date: Date, in plans: [DayPlan], calendar: Calendar = .current) -> DayPlan? {
        let k = dayKey(date, calendar: calendar)
        return plans.last { $0.day == k }
    }

    static func today(_ now: Date = Date()) -> DayPlan? { plan(for: now, in: all()) }

    /// The promise that's running now. A bedtime after midnight (like 4 am)
    /// belongs to the day before: until then, yesterday's promise still runs.
    static func current(_ plans: [DayPlan], now: Date = Date(), calendar: Calendar = .current) -> DayPlan? {
        if let today = plan(for: now, in: plans, calendar: calendar) { return today }
        guard let y = calendar.date(byAdding: .day, value: -1, to: now),
              let last = plan(for: y, in: plans, calendar: calendar),
              last.bedtime < 12 * 60 else { return nil }
        let bedtime = calendar.startOfDay(for: now).addingTimeInterval(TimeInterval(last.bedtime * 60))
        return now < bedtime ? last : nil
    }

    static func current(_ now: Date = Date()) -> DayPlan? { current(all(), now: now) }

    /// "Yesterday" for the morning summary: from yesterday 8 am until this
    /// morning at 8 am (or now), so a late night (sleeping at 4 am) is included.
    static func yesterdayWindow(now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        let today8 = calendar.startOfDay(for: now).addingTimeInterval(TimeInterval(wakeHour * 3600))
        let start = today8.addingTimeInterval(-24 * 3600)
        return DateInterval(start: start, end: max(start.addingTimeInterval(3600), min(now, today8)))
    }

    static func yesterday(_ now: Date = Date(), calendar: Calendar = .current) -> DayPlan? {
        guard let y = calendar.date(byAdding: .day, value: -1, to: now) else { return nil }
        return plan(for: y, in: all(), calendar: calendar)
    }

    /// After 8 am with no promise yet today.
    static func needsPromise(_ plans: [DayPlan], now: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.component(.hour, from: now) >= wakeHour && plan(for: now, in: plans, calendar: calendar) == nil
    }

    /// Adds (or replaces) a day's plan; keeps the last 30 days.
    static func adding(_ plan: DayPlan, to plans: [DayPlan]) -> [DayPlan] {
        Array((plans.filter { $0.day != plan.day } + [plan]).suffix(30))
    }

    static func save(_ plan: DayPlan, _ defaults: UserDefaults = PorkGroup.defaults) {
        if let data = try? JSONEncoder().encode(adding(plan, to: all(defaults))) {
            defaults.set(data, forKey: key)
        }
    }
}

enum Dur {
    /// 2hr 35min, 4hr, 12min
    static func text(_ t: TimeInterval) -> String {
        let mins = max(0, Int(t / 60))
        let h = mins / 60, m = mins % 60
        if h == 0 { return "\(m)min" }
        return m == 0 ? "\(h)hr" : "\(h)hr \(m)min"
    }

    /// 12:40 am
    static func clock(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }
}
