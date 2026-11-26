// Screen Time reports drawn inside the app's Tracker tab (Apple only lets
// this extension see the numbers):
// - today: every app you used today, with its time (distractions red, focus
//   apps green);
// - yesterday: the 2 distraction apps you spent the most time in, as sticky
//   notes, plus total screen time.
// Colors are fixed (dark text on light paper) so they read well in Dark Mode
// too.

import DeviceActivity
import ExtensionKit
import FamilyControls
import ManagedSettings
import SwiftUI

@main
struct PorkReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TopAppsReport { TopAppsView(top: $0) }
        TodayReport { TodayView(day: $0) }
    }
}

extension DeviceActivityReport.Context {
    static let topApps = Self("Pork top apps")
    static let today = Self("Pork today")
}

/// Fixed colors: readable whatever the phone's Dark Mode says.
enum Paper {
    static let page = Color(red: 1.0, green: 0.98, blue: 0.94)
    static let ink = Color(red: 0.13, green: 0.10, blue: 0.08)
    static let muted = Color(red: 0.38, green: 0.34, blue: 0.30)
    static let red = Color(red: 0.80, green: 0.18, blue: 0.14)
    static let green = Color(red: 0.13, green: 0.52, blue: 0.25)
}

/// Your focus apps, saved by the app in the shared App Group.
private func focusAppTokens() -> Set<ApplicationToken> {
    guard let data = PorkGroup.defaults.data(forKey: "focusApps"),
          let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    else { return [] }
    return selection.applicationTokens
}

// MARK: - yesterday's top distractions

struct TopApps {
    var total: TimeInterval = 0
    var distraction: TimeInterval = 0
    var apps: [(name: String, time: TimeInterval)] = []
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
            Text("📱 Yesterday: \(Dur.text(top.total)) screen time · \(Dur.text(top.distraction)) on distractions")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Paper.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Paper.page)
        .environment(\.colorScheme, .light)
    }

    private func note(title: String, time: TimeInterval?, color: Color, tilt: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .lineLimit(2)
            if let time {
                Text(Dur.text(time))
                    .font(.system(.title, design: .rounded).weight(.heavy))
            }
        }
        .foregroundStyle(Paper.ink)
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .background(color, in: RoundedRectangle(cornerRadius: 5))
        .shadow(color: .black.opacity(0.2), radius: 4, x: 1, y: 3)
        .rotationEffect(.degrees(tilt))
    }
}

// MARK: - today: every app, with its time

struct AppTime {
    var name: String
    var time: TimeInterval
    var focus: Bool
    var token: ApplicationToken?
}

struct DaySummary {
    var total: TimeInterval = 0
    var play: TimeInterval = 0
    var apps: [AppTime] = []
    var others = 0          // apps used but not listed (too many to show)
}

struct TodayReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .today
    let content: (DaySummary) -> TodayView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> DaySummary {
        let focus = focusAppTokens()
        var sum = DaySummary()
        var perApp: [String: AppTime] = [:]
        for await device in data {
            for await segment in device.activitySegments {
                sum.total += segment.totalActivityDuration
                for await category in segment.categories {
                    for await app in category.applications {
                        let token = app.application.token
                        let isFocus = token.map { focus.contains($0) } ?? false
                        if !isFocus { sum.play += app.totalActivityDuration }
                        let name = app.application.localizedDisplayName ?? "An app"
                        var row = perApp[name] ?? AppTime(name: name, time: 0, focus: isFocus, token: token)
                        row.time += app.totalActivityDuration
                        perApp[name] = row
                    }
                }
            }
        }
        let used = perApp.values.filter { $0.time >= 60 }.sorted { $0.time > $1.time }
        sum.apps = Array(used.prefix(TodayView.maxRows))
        sum.others = max(0, used.count - TodayView.maxRows)
        return sum
    }
}

struct TodayView: View {
    static let maxRows = 12
    let day: DaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                VStack(alignment: .leading) {
                    Text("Distractions today").font(.caption.weight(.bold)).foregroundStyle(Paper.muted)
                    Text(Dur.text(day.play)).font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .foregroundStyle(Paper.red)
                }
                VStack(alignment: .leading) {
                    Text("Focus apps").font(.caption.weight(.bold)).foregroundStyle(Paper.muted)
                    Text(Dur.text(day.total - day.play)).font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Paper.green)
                }
            }
            if day.apps.isEmpty {
                Text("No app used for a minute yet today 🎉").font(.subheadline).foregroundStyle(Paper.ink)
            }
            let most = day.apps.first?.time ?? 1
            ForEach(Array(day.apps.enumerated()), id: \.offset) { _, app in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        if let token = app.token {
                            Label(token).labelStyle(.iconOnly).frame(width: 22, height: 22)
                        }
                        Text(app.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                            .foregroundStyle(Paper.ink)
                        if app.focus {
                            Text("focus").font(.caption2.bold()).foregroundStyle(Paper.green)
                        }
                        Spacer()
                        Text(Dur.text(app.time)).font(.subheadline.weight(.bold)).monospacedDigit()
                            .foregroundStyle(app.focus ? Paper.green : Paper.red)
                    }
                    GeometryReader { g in
                        Capsule().fill(app.focus ? Paper.green : Paper.red)
                            .frame(width: max(4, g.size.width * app.time / max(most, 1)))
                    }
                    .frame(height: 6)
                }
            }
            if day.others > 0 {
                Text("+ \(day.others) more apps").font(.footnote).foregroundStyle(Paper.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Paper.page)
        .environment(\.colorScheme, .light)
    }
}
