// "Pork's plan": the next event and your to-dos, on the Lock Screen (seen the
// moment the screen lights up) and the Home Screen, with ✓ to tick them off.
// Plus a tiny "💭" Lock Screen widget that opens "Tell Pork…".

import AppIntents
import SwiftUI
import WidgetKit

struct PlanEntry: TimelineEntry {
    let date: Date
    let plan: PlanCache
}

struct PlanProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlanEntry {
        PlanEntry(date: Date(), plan: PlanCache(items: [.init(id: "1", title: "Lab report", tag: "Thu")],
                                                eventTitle: "18.06 lecture", eventStart: Date(), eventEnd: Date()))
    }
    func getSnapshot(in context: Context, completion: @escaping (PlanEntry) -> Void) {
        completion(PlanEntry(date: Date(), plan: PlanCache.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlanEntry>) -> Void) {
        let plan = PlanCache.load()
        var dates = [Date()]
        if let end = plan.eventEnd, end > Date() { dates.append(end) } // drop the event once it's over
        completion(Timeline(entries: dates.map { PlanEntry(date: $0, plan: plan) },
                            policy: .after(Date().addingTimeInterval(30 * 60))))
    }
}

struct PorkPlanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PorkPlan", provider: PlanProvider()) { entry in
            PlanWidgetView(entry: entry)
        }
        .configurationDisplayName("Pork's plan")
        .description("Your next event and to-dos. Tick them off right here.")
        .supportedFamilies([.accessoryRectangular, .systemSmall, .systemMedium, .systemLarge])
    }
}

struct PlanWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PlanEntry

    var body: some View {
        PlanContent(entry: entry)
            .readableOnPaper(family)
            .containerBackground(for: .widget) {
                if family == .accessoryRectangular { Color.clear } else { Color.porkWall }
            }
            .widgetURL(URL(string: "puppypomodoro://open"))
    }
}

/// Next event + to-dos (with ○ to tick on the Home Screen). Also shown by
/// Pork's clock widget when no focus session runs.
struct PlanContent: View {
    @Environment(\.widgetFamily) private var family
    let entry: PlanEntry

    private var event: (title: String, when: String)? {
        guard let t = entry.plan.eventTitle, let s = entry.plan.eventStart,
              let e = entry.plan.eventEnd, e > entry.date else { return nil }
        let when = s <= entry.date ? "now" : s.formatted(date: .omitted, time: .shortened)
        return (t, when)
    }

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                VStack(alignment: .leading, spacing: 1) {
                    if let event {
                        Text("📅 \(event.when) \(event.title)").font(.caption.bold()).lineLimit(1)
                    }
                    ForEach(entry.plan.items.prefix(event == nil ? 3 : 2)) { item in
                        Text("☐ \(item.title)").font(.caption).lineLimit(1)
                    }
                    if entry.plan.items.isEmpty && event == nil {
                        Text("🐾 Nothing waiting. Nice!").font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(family == .systemSmall ? "🐾 To do" : "🐾 Pork's plan").font(.headline)
                        Spacer()
                        if DoneToday.count > 0 { Text("✅ \(DoneToday.count) today").font(.caption.bold()) }
                    }
                    if let event {
                        // The event: dark text on yellow, the time in red, so it can't be missed.
                        HStack(spacing: 6) {
                            Rectangle().fill(Color(red: 0.80, green: 0.15, blue: 0.12)).frame(width: 4)
                            Text(event.when == "now" ? "NOW" : event.when)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(Color(red: 0.80, green: 0.15, blue: 0.12))
                            Text(event.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color(red: 0.10, green: 0.08, blue: 0.06))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 5).padding(.trailing, 6)
                        .background(Color(red: 1, green: 0.88, blue: 0.35), in: RoundedRectangle(cornerRadius: 4))
                    }
                    ForEach(entry.plan.items.prefix(family == .systemLarge ? 8 : family == .systemSmall ? 2 : 3)) { item in
                        HStack(spacing: 8) {
                            Button(intent: CompleteTodoIntent(id: item.id)) {
                                Image(systemName: "circle").font(.body)
                            }
                            .buttonStyle(.plain)
                            Text(item.title).font(.subheadline).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(item.tag).font(.caption2.bold()).foregroundStyle(item.tag.contains("late") ? Color(red: 0.80, green: 0.15, blue: 0.12) : Color(red: 0.30, green: 0.26, blue: 0.22))
                        }
                    }
                    if entry.plan.items.isEmpty {
                        Text("Nothing waiting. Pork is proud 🐾").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

/// 💭 on the Lock Screen: tap to tell Pork a thought.
struct PorkDumpWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PorkDump", provider: PlanProvider()) { _ in
            ZStack {
                AccessoryWidgetBackground()
                Text("💭").font(.title2)
            }
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(URL(string: "puppypomodoro://dump"))
        }
        .configurationDisplayName("Tell Pork")
        .description("Tap to drop a thought into Pork's inbox.")
        .supportedFamilies([.accessoryCircular])
    }
}

extension View {
    /// Home Screen widgets sit on Pork's light "paper" color, so their text
    /// must stay dark even in Dark Mode. (Lock Screen widgets keep the
    /// system's own colors.)
    @ViewBuilder
    func readableOnPaper(_ family: WidgetFamily) -> some View {
        if family.isLockScreen {
            self
        } else {
            self.environment(\.colorScheme, .light)
                .foregroundStyle(Color(red: 0.13, green: 0.10, blue: 0.08))
        }
    }
}
