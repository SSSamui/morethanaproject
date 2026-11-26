// ⏱ Tracker: your time in each app today (from Screen Time), yesterday's top
// distractions, how often you picked up the phone (from the diary), and focus
// time on each project. It only shows facts: nothing here blocks anything.

import DeviceActivity
import FamilyControls
import SwiftUI

extension DeviceActivityReport.Context {
    static let topApps = Self("Pork top apps")
    static let today = Self("Pork today")
}

struct TrackerTab: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var allowed = AuthorizationCenter.shared.authorizationStatus == .approved
    @State private var refresh = Date() // a new filter each time you open the app = fresh numbers
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                section("⏱ Your time today, app by app") {
                    if allowed {
                        // Apple's report can't size itself, so it gets room for 12 apps.
                        DeviceActivityReport(.today, filter: Self.today(refresh))
                            .frame(height: 600)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        allowButton
                    }
                }
                PickUpsCard(tick: model.diaryTick)
                if allowed {
                    section("📌 Yesterday's top distractions") {
                        DeviceActivityReport(.topApps, filter: Self.yesterday)
                            .frame(height: 170)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                if !ProjectTime.list().isEmpty {
                    section("⏱ Time on each project") { ProjectTimes() }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refresh = Date()
                allowed = AuthorizationCenter.shared.authorizationStatus == .approved
            }
        }
    }

    private var allowButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Allow Screen Time so Pork can show how long you spent in each app today. This doesn't block anything.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Allow Screen Time") {
                Task {
                    do {
                        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                        ScreenTime.isOn = true
                    } catch {
                        self.error = "Screen Time wasn't allowed: \(error.localizedDescription)"
                    }
                    allowed = AuthorizationCenter.shared.authorizationStatus == .approved
                }
            }
            .buttonStyle(.borderedProminent).tint(.porkFocus)
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
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

    /// Today from midnight until now.
    private static func today(_ now: Date) -> DeviceActivityFilter {
        let start = Calendar.current.startOfDay(for: now)
        let interval = DateInterval(start: start, end: max(now, start.addingTimeInterval(60)))
        return DeviceActivityFilter(segment: .daily(during: interval), users: .all, devices: .init([.iPhone]))
    }

    private static var yesterday: DeviceActivityFilter {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let interval = cal.dateInterval(of: .day, for: day) ?? DateInterval(start: day, duration: 86_400)
        return DeviceActivityFilter(segment: .daily(during: interval), users: .all, devices: .init([.iPhone]))
    }
}

/// How many times you picked up the phone today (each diary check-in is one).
struct PickUpsCard: View {
    let tick: Int

    var body: some View {
        let today = Diary.all().filter { Calendar.current.isDateInToday($0.started) }
        let skipped = today.filter { $0.kind == .skip }.count
        HStack(spacing: 12) {
            Text("📱").font(.largeTitle)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pick-ups today").font(.caption.bold()).foregroundStyle(.secondary)
                Text("\(today.count)").font(.system(.title, design: .rounded).weight(.heavy))
                Text(today.isEmpty ? "Counted by Pork's unlock check."
                     : "\(today.count - skipped) written · \(skipped) skipped · last at \(Dur.clock(today.map(\.started).max() ?? Date()))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .id(tick)
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
