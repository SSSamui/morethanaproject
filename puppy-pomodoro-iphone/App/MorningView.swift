// Every morning after 8 am, before anything else: today's promise to Pork.
// 1. How much play time today (apps and websites that aren't focus apps),
//    and when we go to sleep tonight.
// 2. Yesterday: screen time per app, play time vs. yesterday's promise, sleep.
// 3. "Start today": today's rules begin (play-time count, bedtime block).
// It covers the whole screen and can't be swiped away.

import SwiftUI
#if !LITE
import DeviceActivity
import FamilyControls
#endif

struct MorningView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0
    @State private var promise = 120     // minutes
    @State private var bedtime = 0       // minutes after midnight

    private let choices = [30, 60, 90, 120, 180]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 1.0, green: 0.93, blue: 0.75), Color.porkWall],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    if step == 0 { promiseStep } else { summaryStep }
                }
                .padding(20)
                .foregroundStyle(.black.opacity(0.85))
            }
        }
        .interactiveDismissDisabled()
        .onAppear {
            if let last = DayPlans.yesterday() { promise = last.promiseMin }
            bedtime = model.state.settings.nightStart
        }
    }

    // MARK: step 1: the promise

    private var promiseStep: some View {
        VStack(spacing: 22) {
            Image("PorkWait").resizable().scaledToFit().frame(height: 130)
            Text("Good morning! ☀️")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
            Text("Pork wants to know: how much play time do you promise him today?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Play time = any app or website that isn't a focus app.")
                .font(.footnote).foregroundStyle(.black.opacity(0.6))

            VStack(spacing: 12) {
                HStack(spacing: 18) {
                    roundButton("minus") { promise = max(15, promise - 15) }
                    Text(Dur.text(TimeInterval(promise * 60)))
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 190)
                    roundButton("plus") { promise = min(12 * 60, promise + 15) }
                }
                HStack(spacing: 8) {
                    ForEach(choices, id: \.self) { m in
                        Button(Dur.text(TimeInterval(m * 60))) { promise = m }
                            .font(.footnote.bold())
                            .buttonStyle(.bordered)
                            .tint(promise == m ? .porkFocus : .gray)
                    }
                }
            }
            .padding(18)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 22))

            VStack(spacing: 8) {
                Text("And when do we go to sleep tonight? 🌙").font(.title3.bold())
                DatePicker("Bedtime", selection: bedtimeBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 120)
                    .clipped()
                Text("After bedtime only focus apps open, until 6:00 am. A bedtime after midnight (like 4 am) still counts as today.")
                    .font(.footnote).foregroundStyle(.black.opacity(0.6))
            }
            .padding(18)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 22))

            Button {
                model.makePromise(minutes: promise, bedtime: bedtime)
                withAnimation(.spring) { step = 1 }
            } label: {
                Text("🐾 I promise, Pork!")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.porkFocus)
        }
    }

    private func roundButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title.bold()).frame(width: 56, height: 56)
        }
        .buttonStyle(.bordered)
        .clipShape(Circle())
    }

    private var bedtimeBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: bedtime / 60, minute: bedtime % 60)) ?? Date() },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                bedtime = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            })
    }

    // MARK: step 2: yesterday

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Promise made! 🐾")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity)
            Text("Today: \(Dur.text(TimeInterval(promise * 60))) of play time · bedtime \(PorkSettings.timeText(bedtime))")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Text("Here's yesterday 📊").font(.title2.bold())
            card { yesterday }
            card { sleep }

            Button {
                model.showMorning = false
                model.show("Pork believes in you! 🐾 \(Dur.text(TimeInterval(promise * 60))) of play today.")
            } label: {
                Text("Start today 🐾")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.porkFocus)
        }
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var yesterday: some View {
        #if LITE
        VStack(alignment: .leading, spacing: 8) {
            if let plan = DayPlans.yesterday() {
                Text("You promised Pork \(Dur.text(TimeInterval(plan.promiseMin * 60))) of play time.")
                    .font(.subheadline.weight(.semibold))
            }
            Text("Opened distraction apps \(Nudges.opensYesterday) times")
                .font(.title3.bold())
            Text("Screen time per app comes with the full version (Screen Time needs the paid Apple developer account).")
                .font(.footnote).foregroundStyle(.black.opacity(0.6))
        }
        #else
        if AuthorizationCenter.shared.authorizationStatus == .approved {
            DeviceActivityReport(.yesterday, filter: Self.yesterdayFilter)
                .frame(minHeight: 380)
        } else {
            Text("Turn on blocking in Settings (it allows Screen Time) to see yesterday's screen time per app.")
                .font(.subheadline)
        }
        #endif
    }

    @ViewBuilder
    private var sleep: some View {
        #if LITE
        if let guess = Nudges.sleepGuess() {
            HStack(spacing: 12) {
                Text("😴").font(.largeTitle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Phone down around \(Dur.clock(guess.sleep)) · up at \(Dur.clock(guess.wake))")
                        .font(.subheadline.weight(.semibold))
                    Text("About \(Dur.text(guess.wake.timeIntervalSince(guess.sleep))) of sleep").font(.title3.bold())
                    Text("Guessed from when you opened apps.").font(.caption).foregroundStyle(.black.opacity(0.55))
                }
            }
        } else {
            Text("😴 Pork will guess your sleep once the Shortcuts automations have run for a night.")
                .font(.subheadline)
        }
        #else
        if AuthorizationCenter.shared.authorizationStatus == .approved {
            DeviceActivityReport(.sleep, filter: Self.sleepFilter)
                .frame(minHeight: 70)
        }
        #endif
    }

    #if !LITE
    /// Yesterday 8 am until this morning (so a late night counts as yesterday).
    private static var yesterdayFilter: DeviceActivityFilter {
        DeviceActivityFilter(segment: .hourly(during: DayPlans.yesterdayWindow()), users: .all, devices: .init([.iPhone]))
    }

    /// Yesterday 6 pm until now, hour by hour.
    private static var sleepFilter: DeviceActivityFilter {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now).addingTimeInterval(-6 * 3600)
        return DeviceActivityFilter(segment: .hourly(during: DateInterval(start: start, end: now)),
                                    users: .all, devices: .init([.iPhone]))
    }
    #endif
}
