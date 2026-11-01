// To-dos from Apple Reminders and the current event from Apple Calendar.
// - "school 2026 fall" list: homework and projects due in the next 7 days
//   (and anything overdue).
// - "routine" list: everyday jobs, shown for today only.
// The list names can be changed in Settings.

import EventKit
import SwiftUI
import WidgetKit

struct TodoItem: Identifiable, Hashable {
    let id: String          // the reminder's identifier
    let title: String
    let due: Date?
    let hasTime: Bool       // due at a time, not just a day
    let routine: Bool
    var link: URL? = nil    // "fun" items: the one link to open
    var days: Int? = nil    // how many days it needs ("Lab report ~3d")
    var inbox = false       // "Tell Pork…" thoughts, not sorted yet

    /// The day to start a task that needs several days.
    var startBy: Date? {
        guard let days, let due else { return nil }
        return TaskSize.startBy(due: due, days: days)
    }

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
    var upcoming: [TodoItem] = []   // every school item with a due date, for the big picture
    var inbox: [TodoItem] = []      // brain dump, to sort into school / routine / fun
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
        let inbox = find(st.inboxList)
        if school == nil { snap.missingLists.append(st.schoolList) }
        if routine == nil { snap.missingLists.append(st.routineList) }
        let wanted = [school, routine, fun, inbox].compactMap { $0 }
        guard !wanted.isEmpty else { return snap }

        let routineID = routine?.calendarIdentifier
        let funID = fun?.calendarIdentifier
        let inboxID = inbox?.calendarIdentifier
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: wanted)
        let items: [TodoItem] = await withCheckedContinuation { done in
            store.fetchReminders(matching: predicate) { reminders in
                let mapped = (reminders ?? []).map { r -> TodoItem in
                    let comps = r.dueDateComponents
                    let due = comps.flatMap { Calendar.current.date(from: $0) }
                    let isFun = r.calendar.calendarIdentifier == funID
                    var title = r.title ?? ""
                    var link: URL? = nil
                    let size = TaskSize.parse(title)
                    if !isFun { title = size.title }
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
                                    link: link,
                                    days: isFun ? nil : size.days,
                                    inbox: r.calendar.calendarIdentifier == inboxID)
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
        snap.inbox = items.filter { $0.inbox }
        let schoolItems = items.filter { !$0.routine && $0.link == nil && !$0.inbox }
        // Today: due today or overdue, today's routine, and bigger tasks whose
        // start day has come ("Lab report ~3d" shows 3 days before it's due).
        let startNow = schoolItems.filter { item in
            guard let due = item.due, due >= endToday, let start = item.startBy else { return false }
            return start < endToday
        }
        snap.today = (schoolItems.filter { $0.due != nil && $0.due! < endToday } + startNow + routineToday).sorted(by: order)
        snap.upcoming = schoolItems.filter { $0.due != nil }.sorted(by: order)
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

    /// "Tell Pork…": put a thought in the Inbox list (made if it's missing).
    static func add(_ title: String, to listName: String) {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasAccess, !text.isEmpty else { return }
        let store = EKEventStore()
        guard let list = list(named: listName, in: store, create: true) else { return }
        let r = EKReminder(eventStore: store)
        r.title = text
        r.calendar = list
        try? store.save(r, commit: true)
    }

    /// Sort an Inbox thought into another list.
    static func move(_ id: String, to listName: String) {
        let store = EKEventStore()
        guard let r = store.calendarItem(withIdentifier: id) as? EKReminder,
              let list = list(named: listName, in: store, create: false) else { return }
        r.calendar = list
        try? store.save(r, commit: true)
    }

    private static func list(named name: String, in store: EKEventStore, create: Bool) -> EKCalendar? {
        if let found = store.calendars(for: .reminder).first(where: {
            $0.title.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(name) == .orderedSame
        }) { return found }
        guard create, let source = store.defaultCalendarForNewReminders()?.source else { return nil }
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = name
        list.source = source
        return (try? store.saveCalendar(list, commit: true)) != nil ? list : nil
    }

    /// The next timed event today (for the plan widget).
    static func nextEvent(now: Date = Date()) -> NowEvent? {
        guard hasCalendar else { return nil }
        let store = EKEventStore()
        let events = store.events(matching: store.predicateForEvents(withStart: now, end: now.addingTimeInterval(16 * 3600), calendars: nil))
            .filter { !$0.isAllDay && $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
        guard let e = events.first else { return nil }
        return NowEvent(title: e.title ?? "Event", start: e.startDate, end: e.endDate, allDay: false,
                        location: e.location?.isEmpty == false ? e.location : nil)
    }

    static func complete(_ id: String) {
        let store = EKEventStore()
        guard let r = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        r.isCompleted = true
        try? store.save(r, commit: true)
    }

    /// An event happening now or starting in the next 15 minutes ("where you
    /// should be"), else today's all-day event.
    static func currentEvent(now: Date = Date()) -> NowEvent? {
        guard hasCalendar else { return nil }
        let store = EKEventStore()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = store.predicateForEvents(withStart: start, end: now.addingTimeInterval(15 * 60), calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        let timed = events.first { !$0.isAllDay && $0.endDate > now && $0.startDate <= now.addingTimeInterval(15 * 60) }
        guard let e = timed ?? events.first(where: { $0.isAllDay && $0.endDate > now }) else { return nil }
        return NowEvent(title: e.title ?? "Event", start: e.startDate, end: e.endDate,
                        allDay: e.isAllDay, location: e.location?.isEmpty == false ? e.location : nil)
    }
}

extension Todos {
    /// Leave a copy of today's plan for the widget.
    static func savePlan(_ snap: TodoSnapshot) {
        var cache = PlanCache()
        let today = Calendar.current.startOfDay(for: Date())
        let soon = snap.today + snap.days.flatMap(\.items)
        cache.items = soon.prefix(8).map { item in
            var tag = item.routine ? "🔁" : ""
            if let due = item.due, !item.routine {
                let days = Calendar.current.dateComponents([.day], from: today, to: Calendar.current.startOfDay(for: due)).day ?? 0
                tag = days < 0 ? "⚠️ late" : days == 0 ? "today" : days == 1 ? "tmrw" : due.formatted(.dateTime.weekday(.abbreviated))
            }
            return PlanCache.Item(id: item.id, title: item.title, tag: tag)
        }
        if let e = nextEvent() {
            cache.eventTitle = e.title
            cache.eventStart = e.start
            cache.eventEnd = e.end
        }
        cache.save()
        WidgetCenter.shared.reloadAllTimelines()
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
        // for Pork's reminders, the paw screen and the plan widget (they can't read Reminders)
        PorkStore.defaults.set(snapshot.preview, forKey: "todoPreview")
        Todos.savePlan(snapshot)
    }

    func requestAccess() async {
        await Todos.requestAccess()
        await refresh()
    }

    func add(_ thought: String) {
        Todos.add(thought, to: PorkStore.load().settings.inboxList)
        Task { await refresh() }
    }

    func move(_ item: TodoItem, to list: String) {
        Todos.move(item.id, to: list)
        Task { await refresh() }
    }

    /// Check one off (it's marked done in Reminders too). Pork celebrates.
    func complete(_ item: TodoItem) {
        Todos.complete(item.id)
        if !item.inbox && item.link == nil {
            DoneToday.add()
            AppModel.shared.celebrate()
        }
        withAnimation(.spring) {
            snapshot.today.removeAll { $0.id == item.id }
            snapshot.days = snapshot.days.compactMap { day in
                let rest = day.items.filter { $0.id != item.id }
                return rest.isEmpty ? nil : TodoDay(date: day.date, items: rest)
            }
            snapshot.noDate.removeAll { $0.id == item.id }
            snapshot.fun.removeAll { $0.id == item.id }
            snapshot.inbox.removeAll { $0.id == item.id }
        }
        // A routine job that repeats comes back with its next date.
        Task { await refresh() }
    }
}
