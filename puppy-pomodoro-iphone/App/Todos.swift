// To-dos from Apple Reminders and the current event from Apple Calendar.
// - "school 2026 fall" list: homework and projects due in the next 7 days
//   (and anything overdue).
// - "routine" list: everyday jobs, shown for today only.
// The list names can be changed in Settings.

import EventKit
import SwiftUI

struct TodoItem: Identifiable, Hashable {
    let id: String          // the reminder's identifier
    let title: String
    let due: Date?
    let hasTime: Bool       // due at a time, not just a day
    let routine: Bool
    var link: URL? = nil    // "fun" items: the one link to open

    func overdue(_ now: Date = Date()) -> Bool {
        guard let due else { return false }
        return hasTime ? due < now : due < Calendar.current.startOfDay(for: now)
    }
}

struct TodoDay: Identifiable, Hashable {
    let date: Date
    let items: [TodoItem]
    var id: Date { date }
}

struct TodoSnapshot {
    var today: [TodoItem] = []      // overdue + due today + today's routine
    var days: [TodoDay] = []        // the next 6 days (school list)
    var noDate: [TodoItem] = []     // school items without a due date
    var fun: [TodoItem] = []        // "fun" list: things to do instead of distractions
    var missingLists: [String] = []

    var isEmpty: Bool { today.isEmpty && days.isEmpty && noDate.isEmpty }
    /// The first few titles, for notifications.
    var preview: [String] { (today + days.flatMap(\.items)).prefix(4).map(\.title) }
}

struct NowEvent: Hashable {
    let title: String
    let start: Date
    let end: Date
    let allDay: Bool
    let location: String?

    func isNow(_ now: Date = Date()) -> Bool { allDay || start <= now }
}

enum Todos {
    static var hasAccess: Bool { EKEventStore.authorizationStatus(for: .reminder) == .fullAccess }
    static var hasCalendar: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    static func requestAccess() async {
        let store = EKEventStore()
        _ = try? await store.requestFullAccessToReminders()
        _ = try? await store.requestFullAccessToEvents()
    }

    /// Reads both lists and sorts them into today, the next days, and no date.
    static func load(_ st: PorkSettings, now: Date = Date()) async -> TodoSnapshot {
        var snap = TodoSnapshot()
        guard hasAccess else { return snap }
        let store = EKEventStore()
        let lists = store.calendars(for: .reminder)
        func find(_ name: String) -> EKCalendar? {
            lists.first { $0.title.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(name) == .orderedSame }
        }
        let school = find(st.schoolList)
        let routine = find(st.routineList)
        let fun = find(st.funList)
        if school == nil { snap.missingLists.append(st.schoolList) }
        if routine == nil { snap.missingLists.append(st.routineList) }
        let wanted = [school, routine, fun].compactMap { $0 }
        guard !wanted.isEmpty else { return snap }

        let routineID = routine?.calendarIdentifier
        let funID = fun?.calendarIdentifier
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: wanted)
        let items: [TodoItem] = await withCheckedContinuation { done in
            store.fetchReminders(matching: predicate) { reminders in
                let mapped = (reminders ?? []).map { r -> TodoItem in
                    let comps = r.dueDateComponents
                    let due = comps.flatMap { Calendar.current.date(from: $0) }
                    let isFun = r.calendar.calendarIdentifier == funID
                    var title = r.title ?? ""
                    var link: URL? = nil
                    if isFun {
                        let parsed = FunLink.parse(title: title, notes: r.notes, url: r.url)
                        title = parsed.title
                        link = parsed.link ?? URL(string: "about:blank") // a fun item without a link
                    }
                    return TodoItem(id: r.calendarItemIdentifier,
                                    title: title,
                                    due: isFun ? nil : due,
                                    hasTime: comps?.hour != nil,
                                    routine: r.calendar.calendarIdentifier == routineID,
                                    link: link)
                }
                done.resume(returning: mapped)
            }
        }

        let cal = Calendar.current
        let startToday = cal.startOfDay(for: now)
        let endToday = cal.date(byAdding: .day, value: 1, to: startToday)!
        let order: (TodoItem, TodoItem) -> Bool = { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }

        // Routine: today only (no date, or due today/earlier).
        let routineToday = items.filter { $0.routine && $0.link == nil && ($0.due == nil || $0.due! < endToday) }
        snap.fun = items.filter { $0.link != nil }
        let schoolItems = items.filter { !$0.routine && $0.link == nil }
        snap.today = (schoolItems.filter { $0.due != nil && $0.due! < endToday } + routineToday).sorted(by: order)
        for d in 1...6 {
            let from = cal.date(byAdding: .day, value: d, to: startToday)!
            let to = cal.date(byAdding: .day, value: 1, to: from)!
            let dayItems = schoolItems.filter { $0.due.map { $0 >= from && $0 < to } ?? false }.sorted(by: order)
            if !dayItems.isEmpty { snap.days.append(TodoDay(date: from, items: dayItems)) }
        }
        snap.noDate = schoolItems.filter { $0.due == nil }
        return snap
    }

    /// To-dos still open for "now": between midnight and 6 am that's
    /// yesterday's list, otherwise today's.
    static func unfinished(_ st: PorkSettings, now: Date = Date()) async -> [TodoItem] {
        let snap = await load(st, now: now)
        let startToday = Calendar.current.startOfDay(for: now)
        let hour = Calendar.current.component(.hour, from: now)
        if hour < 6 {
            return snap.today.filter { ($0.due ?? .distantFuture) < startToday }
        }
        return snap.today
    }

    static func complete(_ id: String) {
        let store = EKEventStore()
        guard let r = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        r.isCompleted = true
        try? store.save(r, commit: true)
    }

    /// An event happening now, else the next one in the coming hour, else
    /// today's all-day event.
    static func currentEvent(now: Date = Date()) -> NowEvent? {
        guard hasCalendar else { return nil }
        let store = EKEventStore()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = store.predicateForEvents(withStart: start, end: now.addingTimeInterval(60 * 60), calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        let timed = events.first { !$0.isAllDay && $0.endDate > now && $0.startDate <= now.addingTimeInterval(60 * 60) }
        guard let e = timed ?? events.first(where: { $0.isAllDay && $0.endDate > now }) else { return nil }
        return NowEvent(title: e.title ?? "Event", start: e.startDate, end: e.endDate,
                        allDay: e.isAllDay, location: e.location?.isEmpty == false ? e.location : nil)
    }
}

/// What the screen shows; refreshed when the app opens.
@MainActor
final class TodoStore: ObservableObject {
    static let shared = TodoStore()

    @Published private(set) var snapshot = TodoSnapshot()
    @Published private(set) var event: NowEvent?
    @Published private(set) var needsAccess = !Todos.hasAccess

    func refresh() async {
        needsAccess = !Todos.hasAccess
        event = Todos.currentEvent()
        guard !needsAccess else { return }
        snapshot = await Todos.load(PorkStore.load().settings)
    }

    func requestAccess() async {
        await Todos.requestAccess()
        await refresh()
    }

    /// Check one off (it's marked done in Reminders too).
    func complete(_ item: TodoItem) {
        Todos.complete(item.id)
        withAnimation(.spring) {
            snapshot.today.removeAll { $0.id == item.id }
            snapshot.days = snapshot.days.compactMap { day in
                let rest = day.items.filter { $0.id != item.id }
                return rest.isEmpty ? nil : TodoDay(date: day.date, items: rest)
            }
            snapshot.noDate.removeAll { $0.id == item.id }
            snapshot.fun.removeAll { $0.id == item.id }
        }
        // A routine job that repeats comes back with its next date.
        Task { await refresh() }
    }
}
