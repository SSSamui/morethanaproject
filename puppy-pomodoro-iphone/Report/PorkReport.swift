// Screen Time report for the day it's given (the app asks for yesterday):
// the 2 distraction apps you spent the most time in, as big sticky notes
// ("YouTube 2hr 35min"), plus total screen time and time on distractions.
// Focus apps (picked in Settings) don't count as distractions.
// Apple only lets this extension see the numbers; it draws them inside the
// app's main screen and Pork's check-in. Full version only (paid account).

import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

@main
struct PorkReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TopAppsReport { TopAppsView(top: $0) }
        YesterdayReport { YesterdayView(day: $0) }
        SleepReport { SleepView(sleep: $0) }
    }
}

extension DeviceActivityReport.Context {
    static let topApps = Self("Pork top apps")
    static let yesterday = Self("Pork yesterday")
    static let sleep = Self("Pork sleep")
}

struct TopApps {
    var total: TimeInterval = 0
    var distraction: TimeInterval = 0
    var apps: [(name: String, time: TimeInterval)] = []
}

/// Your focus apps, saved by the app in the shared App Group.
private func focusAppTokens() -> Set<ApplicationToken> {
    let group = (Bundle.main.object(forInfoDictionaryKey: "PorkAppGroup") as? String) ?? "group.com.sssamui.puppypomodoro"
    guard let data = UserDefaults(suiteName: group)?.data(forKey: "focusApps"),
          let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    else { return [] }
    return selection.applicationTokens
}

struct TopAppsReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .topApps
    let content: (TopApps) -> TopAppsView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TopApps {
        let focus = focusAppTokens()
        var perApp: [String: TimeInterval] = [:]
        var total: TimeInterval = 0
        var distraction: TimeInterval = 0
        for await device in data {
            for await segment in device.activitySegments {
                total += segment.totalActivityDuration
                for await category in segment.categories {
                    for await app in category.applications {
                        if let token = app.application.token, focus.contains(token) { continue }
                        distraction += app.totalActivityDuration
                        let name = app.application.localizedDisplayName ?? "An app"
                        perApp[name, default: 0] += app.totalActivityDuration
                    }
                }
            }
        }
        let top = perApp.sorted { $0.value > $1.value }.prefix(2).map { (name: $0.key, time: $0.value) }
        return TopApps(total: total, distraction: distraction, apps: Array(top))
    }
}

struct TopAppsView: View {
    let top: TopApps

    private let colors = [Color(red: 1.0, green: 0.83, blue: 0.88), Color(red: 1.0, green: 0.88, blue: 0.72)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ForEach(Array(top.apps.enumerated()), id: \.offset) { i, app in
                    note(title: app.name, time: app.time, color: colors[i % colors.count], tilt: i == 0 ? -2 : 1.5)
                }
                if top.apps.isEmpty {
                    note(title: "No distractions yesterday 🎉", time: nil, color: colors[0], tilt: -1)
                }
            }
            Text("📱 Yesterday: \(Self.text(top.total)) screen time · \(Self.text(top.distraction)) on distractions")
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private func note(title: String, time: TimeInterval?, color: Color, tilt: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .lineLimit(2)
            if let time {
                Text(Self.text(time))
                    .font(.system(.title, design: .rounded).weight(.heavy))
            }
        }
        .foregroundStyle(.black.opacity(0.85))
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(color, in: RoundedRectangle(cornerRadius: 5))
        .shadow(color: .black.opacity(0.2), radius: 4, x: 1, y: 3)
        .rotationEffect(.degrees(tilt))
    }

    /// 2hr 35min, 4hr, 12min
    static func text(_ t: TimeInterval) -> String {
        let mins = Int(t / 60)
        let h = mins / 60, m = mins % 60
        if h == 0 { return "\(m)min" }
        return m == 0 ? "\(h)hr" : "\(h)hr \(m)min"
    }
}

// MARK: - yesterday's summary (morning screen)

struct DaySummary {
    var total: TimeInterval = 0
    var play: TimeInterval = 0
    var apps: [(name: String, time: TimeInterval, focus: Bool)] = []
    var promise: DayPlan?
}

struct YesterdayReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .yesterday
    let content: (DaySummary) -> YesterdayView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> DaySummary {
        let focus = focusAppTokens()
        var perApp: [String: (TimeInterval, Bool)] = [:]
        var sum = DaySummary()
        for await device in data {
            for await segment in device.activitySegments {
                sum.total += segment.totalActivityDuration
                for await category in segment.categories {
                    for await app in category.applications {
                        let isFocus = app.application.token.map { focus.contains($0) } ?? false
                        if !isFocus { sum.play += app.totalActivityDuration }
                        let name = app.application.localizedDisplayName ?? "An app"
                        perApp[name] = ((perApp[name]?.0 ?? 0) + app.totalActivityDuration, isFocus)
                    }
                }
            }
        }
        sum.apps = perApp.sorted { $0.value.0 > $1.value.0 }.prefix(10).map { (name: $0.key, time: $0.value.0, focus: $0.value.1) }
        sum.promise = DayPlans.yesterday()
        return sum
    }
}

struct YesterdayView: View {
    let day: DaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading) {
                    Text("Screen time").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Text(Dur.text(day.total)).font(.system(.largeTitle, design: .rounded).weight(.bold))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Play time").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Text(Dur.text(day.play)).font(.system(.title2, design: .rounded).weight(.bold))
                }
            }
            if let promise = day.promise {
                let kept = day.play <= TimeInterval(promise.promiseMin * 60)
                Text(kept
                     ? "✅ You kept your promise to Pork (\(Dur.text(TimeInterval(promise.promiseMin * 60))))."
                     : "🥺 You promised Pork \(Dur.text(TimeInterval(promise.promiseMin * 60))), and played \(Dur.text(day.play - TimeInterval(promise.promiseMin * 60))) more.")
                    .font(.subheadline.weight(.semibold))
            }
            let longest = day.apps.first?.time ?? 1
            ForEach(Array(day.apps.enumerated()), id: \.offset) { _, app in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(app.name).font(.subheadline.weight(.medium))
                        if app.focus { Text("focus").font(.caption2.bold()).foregroundStyle(.green) }
                        Spacer()
                        Text(Dur.text(app.time)).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                    }
                    GeometryReader { g in
                        Capsule().fill(app.focus ? Color.green : Color(red: 0.85, green: 0.26, blue: 0.23))
                            .frame(width: max(4, g.size.width * app.time / max(longest, 1)))
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - sleep (morning screen)

struct SleepInfo {
    var sleep: Date?
    var wake: Date?
}

struct SleepReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .sleep
    let content: (SleepInfo) -> SleepView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> SleepInfo {
        var marks: [UseMark] = []
        for await device in data {
            for await segment in device.activitySegments {
                let start = segment.dateInterval.start
                if segment.totalActivityDuration > 60 {
                    marks.append(UseMark(start: start, end: start.addingTimeInterval(min(3600, segment.totalActivityDuration))))
                }
                if let pickup = segment.firstPickup {
                    marks.append(UseMark(start: pickup, end: pickup))
                }
            }
        }
        let guess = SleepGuess.find(marks)
        return SleepInfo(sleep: guess?.sleep, wake: guess?.wake)
    }
}

struct SleepView: View {
    let sleep: SleepInfo

    var body: some View {
        HStack(spacing: 12) {
            Text("😴").font(.largeTitle)
            if let down = sleep.sleep, let up = sleep.wake {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Phone down around \(Dur.clock(down)) · up at \(Dur.clock(up))")
                        .font(.subheadline.weight(.semibold))
                    Text("About \(Dur.text(up.timeIntervalSince(down))) of sleep")
                        .font(.title3.bold())
                }
            } else {
                Text("Pork couldn't tell when you slept last night.").font(.subheadline)
            }
            Spacer(minLength: 0)
        }
    }
}
