// Sleep countdown: from bedtime (or when you tap "I'm going to sleep") until
// you get up: 8:30 am on weekdays, 10:30 am on weekends (Settings).

import Foundation

enum SleepPlan {
    static func isWeekend(_ date: Date, calendar: Calendar = .current) -> Bool {
        let wd = calendar.component(.weekday, from: date) // 1 = Sunday, 7 = Saturday
        return wd == 1 || wd == 7
    }

    /// The next wake-up time after `date`.
    static func nextWake(after date: Date, weekday: Int, weekend: Int, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: date)
        let t = today.addingTimeInterval(TimeInterval((isWeekend(today, calendar: calendar) ? weekend : weekday) * 60))
        if date < t { return t }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return tomorrow.addingTimeInterval(TimeInterval((isWeekend(tomorrow, calendar: calendar) ? weekend : weekday) * 60))
    }

    /// If it's sleep time now, when to get up. Sleep time starts at bedtime
    /// (minutes after midnight) or when you said you're going to sleep, and
    /// ends at the wake-up time or when you said you're up.
    static func wakeIfSleeping(now: Date, bedtime: Int?, sleptAt: Date?, upAt: Date?,
                               weekday: Int, weekend: Int, calendar: Calendar = .current) -> Date? {
        var starts: [Date] = []
        if let sleptAt { starts.append(sleptAt) }
        if let bedtime {
            // the latest bedtime that already started, within the last 14 hours
            let today = calendar.startOfDay(for: now).addingTimeInterval(TimeInterval(bedtime * 60))
            let last = today <= now ? today : today.addingTimeInterval(-24 * 3600)
            if now.timeIntervalSince(last) < 14 * 3600 { starts.append(last) }
        }
        for start in starts.sorted(by: >) where start <= now {
            if let upAt, upAt >= start { continue }
            let wake = nextWake(after: start, weekday: weekday, weekend: weekend, calendar: calendar)
            if now < wake { return wake }
        }
        return nil
    }
}
