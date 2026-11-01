// How many days a to-do needs, written in its title: "Lab report ~3d",
// "Midterm study (2 days)". Pork then shows when to start: the due date
// minus those days.

import Foundation

enum TaskSize {
    static func parse(_ title: String) -> (title: String, days: Int?) {
        let pattern = #"\s*(?:~\s*(\d+)\s*d(?:ays?)?\b|\((\d+)\s*days?\))"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
              let whole = Range(m.range, in: title) else { return (title, nil) }
        let numRange = m.range(at: 1).location != NSNotFound ? m.range(at: 1) : m.range(at: 2)
        guard let r = Range(numRange, in: title), let days = Int(title[r]), days > 0 else { return (title, nil) }
        var clean = title
        clean.removeSubrange(whole)
        return (clean.trimmingCharacters(in: .whitespaces), days)
    }

    /// The day to start: `days` working days before the due day.
    static func startBy(due: Date, days: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: due)) ?? due
    }
}
