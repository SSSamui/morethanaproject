// Small shared records: to-dos finished today, the plan widget's copy of
// your to-dos and next event, and focus time on each project.

import Foundation

/// To-dos finished today (Pork celebrates them).
enum DoneToday {
    private static var d: UserDefaults { PorkStore.defaults }

    static var count: Int {
        d.string(forKey: "doneDay") == Days.key(Date()) ? d.integer(forKey: "doneCount") : 0
    }

    static func add() {
        let today = Days.key(Date())
        if d.string(forKey: "doneDay") != today {
            d.set(today, forKey: "doneDay")
            d.set(0, forKey: "doneCount")
        }
        d.set(d.integer(forKey: "doneCount") + 1, forKey: "doneCount")
    }
}

/// What the plan widget shows (it can't read Reminders or Calendar itself,
/// so the app leaves a copy here).
struct PlanCache: Codable {
    struct Item: Codable, Hashable, Identifiable {
        var id: String
        var title: String
        var tag: String
    }
    var items: [Item] = []
    var eventTitle: String?
    var eventStart: Date?
    var eventEnd: Date?

    static func load() -> PlanCache {
        guard let data = PorkStore.defaults.data(forKey: "planCache"),
              let c = try? JSONDecoder().decode(PlanCache.self, from: data) else { return PlanCache() }
        return c
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { PorkStore.defaults.set(data, forKey: "planCache") }
    }
}

/// Focus time spent on each to-do (project), from focus sessions started
/// with ▶︎ on its sticky note.
enum ProjectTime {
    struct Entry: Codable { var title: String; var seconds: TimeInterval; var last: Date }
    private static var d: UserDefaults { PorkStore.defaults }

    static func all() -> [String: Entry] {
        guard let data = d.data(forKey: "projectTime"),
              let v = try? JSONDecoder().decode([String: Entry].self, from: data) else { return [:] }
        return v
    }

    static func add(_ id: String, _ title: String, _ seconds: TimeInterval, now: Date = Date()) {
        guard seconds > 0 else { return }
        var v = all()
        var e = v[id] ?? Entry(title: title, seconds: 0, last: now)
        e.title = title
        e.seconds += seconds
        e.last = now
        v[id] = e
        if let data = try? JSONEncoder().encode(v) { d.set(data, forKey: "projectTime") }
    }

    static func total(_ id: String) -> TimeInterval { all()[id]?.seconds ?? 0 }

    /// Most recent first.
    static func list() -> [(id: String, title: String, seconds: TimeInterval)] {
        all().sorted { $0.value.last > $1.value.last }.map { ($0.key, $0.value.title, $0.value.seconds) }
    }
}
