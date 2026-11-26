// Small helpers shared by the app and every extension: the App Group, the
// day key ("2026-11-26") and time text ("2hr 35min", "8:42 am").

import Foundation

/// The App Group shared by the app and its extensions.
enum PorkGroup {
    static let id = (Bundle.main.object(forInfoDictionaryKey: "PorkAppGroup") as? String)
        ?? "group.com.sssamui.puppypomodoro"
    static var defaults: UserDefaults { UserDefaults(suiteName: id) ?? .standard }
}

enum Days {
    /// "2026-11-26"
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
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

    /// 8:42 am
    static func clock(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }
}
