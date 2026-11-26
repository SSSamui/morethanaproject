// 📔 Diary: what you wrote each time you picked up the phone, newest day
// first, with the time. Also: how many days you wrote this week, "one week
// ago you wrote…", and when you pick up the phone most.

import SwiftUI

struct DiaryTab: View {
    @EnvironmentObject private var model: AppModel
    @State private var days: [DiaryDay] = []
    @State private var all: [DiaryEntry] = []
    @State private var levelHintHidden = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    Gate.noteStart()
                    model.showWrite = true
                } label: {
                    Label("Write to Pork now", systemImage: "square.and.pencil")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent).tint(.porkFocus).controlSize(.large)

                if !Gate.settings.on {
                    card {
                        Text("🔒 The unlock check is off").font(.headline)
                        Text("Turn it on in Settings (⚙︎) → Unlock check, so Pork asks for a photo or a sentence when you open an app.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else if Gate.skippedToday {
                    card {
                        Text("⏭ Skipped for today").font(.headline)
                        Text("Pork asks again from tomorrow.").font(.subheadline).foregroundStyle(.secondary)
                        Button("Turn it back on now") { Gate.skipToday(false); reload() }.buttonStyle(.bordered)
                    }
                }

                summary
                levelHint
                weekAgo

                if days.isEmpty {
                    card {
                        Text("Nothing yet 🐾").font(.headline)
                        Text("Each time you write to Pork, it shows here with the time. Over a few days you'll see what's been going on.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                ForEach(days) { day in
                    DiaryDayCard(day: day)
                }
                Text(DiaryExport.inICloud
                     ? "A copy is in Files → iCloud Drive → Pork Diary."
                     : "A copy is in Files → On My iPhone → Puppy Pomodoro → Pork Diary.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear(perform: reload)
        .onChange(of: model.diaryTick) { _, _ in reload() }
    }

    private func reload() {
        all = Diary.all()
        days = Diary.days(all)
        levelHintHidden = PorkStore.defaults.string(forKey: "levelHintWeek") == weekKey
    }

    private var weekKey: String {
        let c = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return "\(c.yearForWeekOfYear ?? 0)-\(c.weekOfYear ?? 0)"
    }

    /// "Wrote 5 of the last 7 days · 23 check-ins this week · most around 11 pm"
    private var summary: some View {
        let written = Diary.daysWritten(lastWeek: all)
        let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        let week = all.filter { $0.started >= weekStart }
        let today = all.filter { Calendar.current.isDateInToday($0.started) }
        let hours = Dictionary(grouping: week) { Calendar.current.component(.hour, from: $0.started) }
        let busiest = hours.max { $0.value.count < $1.value.count }?.key
        return Group {
            if !all.isEmpty {
                card {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading) {
                            Text("Today").font(.caption.bold()).foregroundStyle(.secondary)
                            Text("\(today.filter { $0.kind != .skip }.count) written").font(.title2.bold())
                            if today.contains(where: { $0.kind == .skip }) {
                                Text("\(today.filter { $0.kind == .skip }.count) skipped").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Last 7 days").font(.caption.bold()).foregroundStyle(.secondary)
                            Text("🐾 \(written) of 7 days").font(.title2.bold())
                        }
                    }
                    if let busiest, week.count >= 5 {
                        Text("This week: \(week.count) pick-ups · most around \(hourText(busiest))")
                            .font(.subheadline)
                    }
                    if written == 0 {
                        Text("Welcome back 🐾 Pork missed you.").font(.subheadline)
                    }
                }
            }
        }
    }

    /// After 7 days in a row: Pork suggests the next level (only suggests).
    private var levelHint: some View {
        let level = Gate.settings.level
        let ready = Diary.daysWritten(lastWeek: all) >= 7 && level < 4 && !levelHintHidden
        return Group {
            if ready {
                card {
                    Text("🌟 7 days in a row!").font(.headline)
                    Text("Ready to try “\(DiaryLevel.title(level + 1))”? You can go back any time in Settings.")
                        .font(.subheadline)
                    HStack {
                        Button("Try it") {
                            var g = Gate.settings
                            g.level = level + 1
                            Gate.settings = g
                            hideHint()
                        }
                        .buttonStyle(.borderedProminent).tint(.porkFocus)
                        Button("Not yet") { hideHint() }.buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func hideHint() {
        PorkStore.defaults.set(weekKey, forKey: "levelHintWeek")
        levelHintHidden = true
    }

    /// "One week ago you wrote…"
    private var weekAgo: some View {
        let cal = Calendar.current
        let target = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let old = all.filter { $0.kind != .skip && !$0.text.isEmpty && cal.isDate($0.started, inSameDayAs: target) }
        return Group {
            if let e = old.randomElement() {
                card {
                    Text("📅 One week ago you wrote…").font(.caption.bold()).foregroundStyle(.secondary)
                    Text("“\(e.text)”").font(.body.italic())
                    Text("\(e.started.formatted(.dateTime.weekday(.wide))) · \(Dur.clock(e.started))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func hourText(_ h: Int) -> String {
        Dur.clock(Calendar.current.date(from: DateComponents(hour: h)) ?? Date())
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// One day of the diary.
struct DiaryDayCard: View {
    let day: DiaryDay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            ForEach(day.entries) { e in
                HStack(alignment: .top, spacing: 10) {
                    Text(Dur.clock(e.started))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(e.kind == .skip ? Color.secondary : Color.porkFocus)
                        .frame(width: 74, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        switch e.kind {
                        case .skip:
                            Text("⏭ skipped").font(.subheadline).foregroundStyle(.secondary)
                        case .text, .photo:
                            if let mood = e.mood { Text(mood).font(.caption.bold()) }
                            if !e.text.isEmpty { Text(e.text).font(.body) }
                            if let name = e.photo, let img = UIImage(contentsOfFile: Diary.photoURL(name).path) {
                                Image(uiImage: img).resizable().scaledToFill()
                                    .frame(maxWidth: 220, maxHeight: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var title: String {
        if Calendar.current.isDateInToday(day.date) { return "Today" }
        if Calendar.current.isDateInYesterday(day.date) { return "Yesterday" }
        return day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
