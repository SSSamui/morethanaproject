// Home Screen and Lock Screen widget: Pork and the clock.

import SwiftUI
import WidgetKit

struct PorkEntry: TimelineEntry {
    let date: Date
    let state: PorkState
    /// After 10 pm: time to sleep; after bedtime: sleep left.
    var night: PorkMoment? {
        let st = state.settings
        if let bedtime = SleepMode.bedtimeSoon(st, now: date) {
            return PorkMoment(phase: "bedtime", paused: false, target: bedtime, pausedLeft: 0,
                              carry: 0, bonusEveryMin: st.bonusEveryMin, stale: false)
        }
        if let wake = SleepMode.wake(st, now: date) {
            return PorkMoment(phase: "sleep", paused: false, target: wake, pausedLeft: 0,
                              carry: 0, bonusEveryMin: st.bonusEveryMin, stale: false)
        }
        return nil
    }

    /// Home Screen: the clock, or the night countdowns when no session runs.
    var moment: PorkMoment {
        let clock = PorkMoment(state, at: date)
        return clock.kind == .idle ? (night ?? clock) : clock
    }

    /// Lock Screen: after 10 pm the bedtime / sleep countdown comes first.
    var lockMoment: PorkMoment { night ?? moment }
}

struct PorkProvider: TimelineProvider {
    func placeholder(in context: Context) -> PorkEntry {
        PorkEntry(date: Date(), state: PorkState())
    }

    func getSnapshot(in context: Context, completion: @escaping (PorkEntry) -> Void) {
        completion(PorkEntry(date: Date(), state: PorkStore.load()))
    }

    // One entry now, plus one for each moment Pork changes pose by himself.
    func getTimeline(in context: Context, completion: @escaping (Timeline<PorkEntry>) -> Void) {
        let s = PorkStore.load()
        let now = Date()
        var dates = [now]
        if !s.paused {
            switch s.phase {
            case .focus:
                if let goal = s.endsAt, goal > now { dates.append(goal) }
            case .break:
                if let end = s.endsAt {
                    dates += [end, end.addingTimeInterval(paceSeconds)].filter { $0 > now }
                }
            case .overtime:
                if let from = s.overtimeFrom, from.addingTimeInterval(paceSeconds) > now {
                    dates.append(from.addingTimeInterval(paceSeconds))
                }
            case .idle:
                break
            }
        }
        dates += SleepMode.changes(s.settings, now: now)
        let entries = Array(Set(dates)).sorted().map { PorkEntry(date: $0, state: s) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
    }
}

struct PorkClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PorkClock", provider: PorkProvider()) { entry in
            PorkWidgetView(entry: entry)
        }
        .configurationDisplayName("Pork's clock")
        .description("Pork and your focus clock.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct PorkWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PorkEntry

    var body: some View {
        let m = family.isLockScreen ? entry.lockMoment : entry.moment
        Group {
            switch family {
            case .systemMedium:
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(m.label.uppercased()).font(.caption2.bold()).foregroundStyle(m.color)
                        Spacer()
                        m.timer.font(.title2.bold()).monospacedDigit().foregroundStyle(m.color)
                            .multilineTextAlignment(.trailing)
                    }
                    Image(m.roomImage).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            case .accessoryRectangular:
                HStack {
                    VStack(alignment: .leading) {
                        Text(m.label).font(.caption2.bold())
                        m.timer.font(.title3.bold()).monospacedDigit()
                    }
                    Spacer(minLength: 0)
                }
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Text(m.kind == .bedtime || m.kind == .sleep ? "🌙" : "🐾").font(.caption2)
                    Text(m.short).font(.caption.bold()).minimumScaleFactor(0.6)
                }
            case .accessoryInline:
                if m.kind == .bedtime || m.kind == .sleep {
                    Text(m.kind == .bedtime ? "🌙 Sleep in " : "😴 Sleep left ") + m.timer
                } else {
                    Text("🐾 \(m.label) · \(m.short)")
                }
            default:
                VStack(spacing: 2) {
                    Text(m.label.uppercased()).font(.caption2.bold()).foregroundStyle(m.color)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    m.timer.font(.system(size: 26, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(m.color).multilineTextAlignment(.center)
                    Image(m.porkImage).resizable().scaledToFit().frame(maxHeight: 64)
                    Text(m.line).font(.system(size: 10)).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
        .containerBackground(for: .widget) {
            if family == .systemSmall || family == .systemMedium { Color.porkWall } else { Color.clear }
        }
        .widgetURL(URL(string: "puppypomodoro://open"))
    }
}

extension WidgetFamily {
    var isLockScreen: Bool {
        self == .accessoryInline || self == .accessoryRectangular || self == .accessoryCircular
    }
}
