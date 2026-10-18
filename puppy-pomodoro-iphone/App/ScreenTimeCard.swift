// "Yesterday's top distractions": the Screen Time report (Report/) shown on
// the main screen and in Pork's check-in. Full version only: Screen Time
// needs a paid Apple developer account.

import SwiftUI
#if !LITE
import DeviceActivity
import FamilyControls

extension DeviceActivityReport.Context {
    static let topApps = Self("Pork top apps")
}
#endif

struct ScreenTimeCard: View {
    #if !LITE
    @State private var allowed = AuthorizationCenter.shared.authorizationStatus == .approved
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("⏱ Yesterday's top distractions").font(.title3.bold())
            #if LITE
            Text("Your 2 biggest distractions from yesterday (like “YouTube 2hr 35min”) and your screen time show here in the full version. Screen Time needs a paid Apple developer account.")
                .font(.footnote).foregroundStyle(.secondary)
            #else
            if allowed {
                DeviceActivityReport(.topApps, filter: yesterday)
                    .frame(minHeight: 180)
            } else {
                Text("Allow Screen Time so Pork can show yesterday's 2 biggest distractions and your screen time.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Allow Screen Time") {
                    Task {
                        try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                        allowed = AuthorizationCenter.shared.authorizationStatus == .approved
                    }
                }
                .buttonStyle(.borderedProminent).tint(.porkFocus)
            }
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    #if !LITE
    private var yesterday: DeviceActivityFilter {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let interval = cal.dateInterval(of: .day, for: day) ?? DateInterval(start: day, duration: 86_400)
        return DeviceActivityFilter(segment: .daily(during: interval), users: .all, devices: .init([.iPhone]))
    }
    #endif
}
