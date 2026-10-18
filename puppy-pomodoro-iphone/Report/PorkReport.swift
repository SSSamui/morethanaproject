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
    }
}

extension DeviceActivityReport.Context {
    static let topApps = Self("Pork top apps")
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
