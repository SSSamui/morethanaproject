// The Live Activity: the clock with Pork on the Lock Screen and in the
// Dynamic Island (the iPhone version of the time next to the address bar).
// It switches by itself when the focus goal is reached (gold +00:01…) and when
// the break runs out (red −00:01…).

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct PorkLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PorkActivityAttributes.self) { context in
            LockScreenPork(m: moment(context))
                .activityBackgroundTint(Color.porkWall.opacity(0.92))
                .activitySystemActionForegroundColor(.black)
        } dynamicIsland: { context in
            let m = moment(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(m.porkImage).resizable().scaledToFit().frame(height: 52)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    m.timer
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(m.color)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 130, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(m.label).font(.caption.bold()).foregroundStyle(m.color)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(m.line).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        Spacer()
                        PorkButton(m: m)
                    }
                }
            } compactLeading: {
                Image("PorkFace").resizable().scaledToFit().frame(width: 24, height: 24)
            } compactTrailing: {
                m.timer
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(m.color)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 54)
            } minimal: {
                Image("PorkFace").resizable().scaledToFit().frame(width: 22, height: 22)
            }
            .keylineTint(m.color)
            .widgetURL(URL(string: "puppypomodoro://open"))
        }
    }

    private func moment(_ context: ActivityViewContext<PorkActivityAttributes>) -> PorkMoment {
        let s = context.state
        return PorkMoment(phase: s.phase, paused: s.paused, target: s.target, pausedLeft: s.pausedLeft,
                          carry: s.carry, bonusEveryMin: s.bonusEveryMin, stale: context.isStale)
    }
}

struct LockScreenPork: View {
    let m: PorkMoment

    var body: some View {
        HStack(spacing: 12) {
            Image(m.porkImage).resizable().scaledToFit().frame(width: 84, height: 62)
            VStack(alignment: .leading, spacing: 2) {
                Text(m.label.uppercased())
                    .font(.caption2.weight(.bold)).foregroundStyle(m.color)
                m.timer
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(m.color)
                Text(m.line).font(.caption).foregroundStyle(.black.opacity(0.6)).lineLimit(1)
            }
            Spacer(minLength: 0)
            PorkButton(m: m)
        }
        .padding(14)
        .widgetURL(URL(string: "puppypomodoro://open"))
    }
}

/// The button that fits the moment.
struct PorkButton: View {
    let m: PorkMoment

    var body: some View {
        Group {
            if m.paused {
                Button(intent: ResumeIntent()) { Text("Resume") }.tint(.porkFocus)
            } else {
                switch m.kind {
                case .focus:
                    Button(intent: PauseIntent()) { Text("Pause") }.tint(.gray)
                case .extra:
                    Button(intent: TakeBreakIntent()) { Text("Take a break") }.tint(.porkBonus)
                case .rest:
                    Button(intent: LetPorkOutIntent()) { Text("Back to focus") }.tint(.porkBreak)
                case .over:
                    Button(intent: LetPorkOutIntent()) { Text("🐾 Let Pork out") }.tint(.porkOver)
                case .idle:
                    EmptyView()
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .font(.caption.bold())
    }
}
