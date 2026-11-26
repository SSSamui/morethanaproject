// 📝 Reminder: where you should be (the event on now, today's calendar) and
// what to do (sticky notes from Reminders, the big picture, the inbox).

import SwiftUI

struct ReminderTab: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var todos: TodoStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let event = todos.event {
                    BigEventNote(event: event)
                }
                HStack(spacing: 10) {
                    Button { model.showDump = true } label: {
                        Label("Tell Pork…", systemImage: "bubble.left.and.text.bubble.right")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(.porkFocus)
                    if DoneToday.count > 0 {
                        Text("✅ \(DoneToday.count) today").font(.subheadline.bold())
                    }
                }
                section("📝 To do this week") { StickyBoard(todos: todos) }
                if !todos.dayEvents.isEmpty {
                    section("📅 Today's calendar") { DayCalendar(events: todos.dayEvents) }
                }
                if !todos.snapshot.upcoming.isEmpty {
                    section("📅 Big picture: next 3 weeks") { BigPictureView(todos: todos) }
                }
                if !todos.snapshot.inbox.isEmpty {
                    section("💭 Inbox: give these a home") { InboxSorter(todos: todos) }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable { await todos.refresh() }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Today's events, as a list: past ones faded, the one on now highlighted.
struct DayCalendar: View {
    let events: [NowEvent]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            VStack(alignment: .leading, spacing: 8) {
                ForEach(events, id: \.self) { e in
                    let now = e.start <= ctx.date && e.end > ctx.date
                    let past = e.end <= ctx.date
                    HStack(alignment: .top, spacing: 10) {
                        Text(e.allDay ? "all day" : Dur.clock(e.start))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .frame(width: 74, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.title).font(.subheadline.weight(now ? .heavy : .semibold))
                            if let loc = e.location {
                                Text("📍 \(loc)").font(.caption).foregroundStyle(now ? Color.black.opacity(0.6) : Color.secondary)
                            }
                        }
                        Spacer()
                        if now { Text("NOW").font(.caption.weight(.heavy)).foregroundStyle(Color.porkOver) }
                    }
                    .padding(8)
                    .background(now ? Color(red: 1, green: 0.88, blue: 0.35) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(now ? Color.black : Color.primary)
                    .opacity(past ? 0.4 : 1)
                }
            }
        }
    }
}
