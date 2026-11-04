// Pork's board: the outside brain. Everything visible on one screen:
// where you should be, your time today and this pick-up, to-dos for the
// week, the fun list, Pork, and the 30-minute pause.

import SwiftUI
#if !LITE
import DeviceActivity
import FamilyControls
#endif

struct BoardView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var todos: TodoStore

    var body: some View {
        VStack(spacing: 14) {
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
            SleepCard()
            if let event = todos.event {
                BigEventNote(event: event)
            }
            TimeCard()
            if !todos.dayEvents.isEmpty {
                section("📅 Today's calendar") { DayCalendar(events: todos.dayEvents) }
            }
            section("📝 To do this week") { StickyBoard(todos: todos) }
            section("📅 Big picture: next 3 weeks") { BigPictureView(todos: todos) }
            if !ProjectTime.list().isEmpty {
                section("⏱ Time on each project") { ProjectTimes() }
            }
            if !todos.snapshot.inbox.isEmpty {
                section("💭 Inbox: give these a home") { InboxSorter(todos: todos) }
            }
            section("🎈 Fun instead of scrolling") { FunBoard(todos: todos) }
            PromiseCard()
            PorkCorner()
            ScreenTimeCard()
            if StrictRules.limitsOn() || PorkPause.isOn { PauseBar() }
        }
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

/// ⏸ Pause 30 min / paused until 3:42 pm.
struct PauseBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            if let until = PorkPause.until {
                HStack {
                    Text("⏸ Paused until \(Dur.clock(until)) · no gates or reminders")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Resume") { model.pause(false) }.buttonStyle(.bordered)
                }
                .padding(12)
                .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Button { model.pause(true) } label: {
                    Label("Pause Pork for 30 min", systemImage: "pause.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

/// Distraction time today and in this pick-up (always visible on the board,
/// the Lock Screen widget and the Lock Screen countdown).
struct TimeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("⏱ Your time").font(.title3.bold())
            #if !LITE
            if AuthorizationCenter.shared.authorizationStatus == .approved {
                DeviceActivityReport(.today, filter: Self.today).frame(minHeight: 300)
            } else {
                Text("Turn on blocking in Settings to see your real minutes.").font(.footnote).foregroundStyle(.secondary)
            }
            #else
            Text("Opened distraction apps \(Nudges.opensToday) times today")
                .font(.title3.bold())
            Text("Real minutes come with the full version (Screen Time).")
                .font(.footnote).foregroundStyle(.secondary)
            #endif
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                if let start = PickUp.start, PickUp.isActive(ctx.date) {
                    HStack {
                        Text("📱 This pick-up").font(.headline)
                        Spacer()
                        Text(PorkClock.text(ctx.date.timeIntervalSince(start)))
                            .font(.system(.title2, design: .rounded).weight(.bold)).monospacedDigit()
                    }
                    #if !LITE
                    if PickUp.minutes > 0 {
                        Text("\(PickUp.minutes) min on distractions this time")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    #endif
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    #if !LITE
    private static var today: DeviceActivityFilter {
        let interval = Calendar.current.dateInterval(of: .day, for: Date()) ?? DateInterval(start: Date(), duration: 86_400)
        return DeviceActivityFilter(segment: .daily(during: interval), users: .all, devices: .init([.iPhone]))
    }
    #endif
}

/// Pork's room shows how you're doing: napping when you're fine, waiting by
/// the door during a pick-up, scratching after 5 minutes. Tap for his photos.
struct PorkCorner: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { ctx in
            VStack(spacing: 8) {
                RoomView(pose: pose(ctx.date), goal: false)
                    .aspectRatio(360 / 200, contentMode: .fit)
                Button("🐶 Pork's photos") { model.showHi = true }
                    .font(.footnote.weight(.semibold))
            }
        }
    }

    private func pose(_ now: Date) -> Pose {
        if SleepMode.wake(model.state.settings, now: now) != nil { return .sleep }
        guard !PorkPause.isOn, PickUp.isActive(now), let start = PickUp.start else { return .sleep }
        return now.timeIntervalSince(start) >= TimeInterval(model.state.settings.nudgeMin * 60) ? .door : .wait
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
                            if let loc = e.location { Text("📍 \(loc)").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        if now { Text("NOW").font(.caption.weight(.heavy)).foregroundStyle(Color.porkOver) }
                    }
                    .padding(8)
                    .background(now ? Color(red: 1, green: 0.95, blue: 0.62) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(now ? Color.black : Color.primary)
                    .opacity(past ? 0.4 : 1)
                }
            }
        }
    }
}

/// Focus time per to-do, from ▶︎ Focus on its sticky note.
struct ProjectTimes: View {
    var body: some View {
        let list = Array(ProjectTime.list().prefix(8))
        let most = list.map(\.seconds).max() ?? 1
        VStack(alignment: .leading, spacing: 8) {
            ForEach(list, id: \.id) { p in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(p.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Spacer()
                        Text(Dur.text(p.seconds)).font(.subheadline.weight(.bold)).monospacedDigit()
                    }
                    GeometryReader { g in
                        Capsule().fill(Color.porkFocus).frame(width: max(6, g.size.width * p.seconds / most))
                    }
                    .frame(height: 6)
                }
            }
            Text("Tap ▶︎ Focus on a sticky note to count time for it.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
