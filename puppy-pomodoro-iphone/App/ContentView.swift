// The main screen: clock, Pork's room, buttons and the treat jar.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    TimelineView(.periodic(from: .now, by: 0.25)) { context in
                        PorkScreen(now: context.date)
                    }
                    TreatJarView()
                    #if !LITE
                    if !ScreenTime.isOn {
                        Button { showSettings = true } label: {
                            Label("Turn on blocking so only focus apps and sites open while you focus",
                                  systemImage: "lock.shield")
                                .font(.footnote)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                    #endif
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("🐾 Puppy Pomodoro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .fullScreenCover(isPresented: $model.showHi) { PorkHiView() }
            .overlay(alignment: .top) {
                if let toast = model.toast {
                    Text(toast)
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { model.toast = nil }
                }
            }
            .animation(.spring, value: model.toast)
        }
    }
}

/// Everything that changes every second.
struct PorkScreen: View {
    @EnvironmentObject private var model: AppModel
    let now: Date

    var body: some View {
        // The saved state, caught up to now (the break may have just run out).
        let s = model.state.advanced(to: now)
        let releasing = now < model.releasingUntil
        let pose: Pose = releasing ? .out : s.pose(now)
        let goal = s.goalReached(now)
        let color = clockColor(s, goal)
        let scratching = pose == .door && s.settings.sound

        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(label(s, goal).uppercased())
                    .font(.caption.weight(.bold)).tracking(1)
                    .foregroundStyle(s.phase == .idle ? Color.secondary : color)
                Text(PorkClock.display(s, now))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(s.phase == .idle ? Color.primary : color)
                    .opacity(s.phase == .overtime && Int(now.timeIntervalSince1970 * 2) % 2 == 0 ? 0.6 : 1)
                    .contentTransition(.numericText())
                Text(sub(s, goal))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 34, alignment: .top)
            }

            RoomView(pose: pose, goal: goal)
                .aspectRatio(360 / 200, contentMode: .fit)
                .accessibilityLabel(roomDescription(pose))

            ControlsView(state: s, goal: goal)
        }
        .onChange(of: scratching, initial: true) { _, on in ScratchPlayer.shared.set(on) }
        // Break ran out while watching: save it, so the reminders, Lock Screen and
        // widgets switch to "break is over" too.
        .onChange(of: s.phase) { _, _ in model.send(.sync) }
    }

    private func clockColor(_ s: PorkState, _ goal: Bool) -> Color {
        if s.paused { return .gray }
        switch s.phase {
        case .idle, .focus: return goal ? .porkBonus : .porkFocus
        case .break: return .porkBreak
        case .overtime: return .porkOver
        }
    }

    private func label(_ s: PorkState, _ goal: Bool) -> String {
        let p = s.paused ? " · paused" : ""
        switch s.phase {
        case .idle: return "Ready to focus"
        case .focus: return (goal ? "Extra focus" : "Focus") + p
        case .break: return "Break" + p
        case .overtime: return "Break is over!"
        }
    }

    private func sub(_ s: PorkState, _ goal: Bool) -> String {
        switch s.phase {
        case .idle:
            return s.sessions > 0 ? "\(s.sessions) focus session\(s.sessions > 1 ? "s" : "") done" : "Pork naps while you focus."
        case .focus where !goal:
            return s.carry > 0
                ? "\(PorkClock.text(TimeInterval(s.settings.focusMin * 60))) + \(PorkClock.text(s.carry)) from the long break"
                : "Only focus apps and sites until the goal 🐶"
        case .focus:
            let n = s.earned(now)
            return "Pork earned \(PorkClock.treatsText(n)) · next treat in \(PorkClock.text(s.nextTreatIn(now))). Open another app to take your break."
        case .break:
            return "Pork is waiting by the door 🚪"
        case .overtime:
            return s.lateBy(now) < paceSeconds
                ? "Pork is pacing, he wants to go out! This time gets added to your next focus."
                : "Pork is scratching the door! This time gets added to your next focus."
        }
    }

    private func roomDescription(_ pose: Pose) -> String {
        switch pose {
        case .sleep: return "Pork is napping on his bed"
        case .wait: return "Pork is sitting by the glass door, looking outside"
        case .pace: return "Pork is walking back and forth"
        case .door: return "Pork is standing up, scratching the door"
        case .out: return "The door opens and Pork runs outside"
        }
    }
}

struct ControlsView: View {
    @EnvironmentObject private var model: AppModel
    let state: PorkState
    let goal: Bool

    var body: some View {
        VStack(spacing: 10) {
            if state.phase == .idle {
                ViewThatFits {
                    HStack(spacing: 12) {
                        minutes("Focus", \.focusMin, 1...180)
                        minutes("Break", \.breakMin, 1...60)
                    }
                    VStack(spacing: 8) {
                        minutes("Focus", \.focusMin, 1...180)
                        minutes("Break", \.breakMin, 1...60)
                    }
                }
                big("▶ Start focus", .porkFocus) { model.send(.start(nil)) }
            }
            if state.phase == .overtime {
                big("🐾 End the fun — let Pork out", .porkOver) { model.send(.release) }
                    .phaseAnimator([1.0, 1.04]) { view, scale in view.scaleEffect(scale) }
            }
            HStack(spacing: 10) {
                if state.phase == .focus || state.phase == .break {
                    if state.paused {
                        small("Resume", .porkFocus, filled: true) { model.send(.resume) }
                    } else {
                        small("Pause") { model.send(.pause) }
                    }
                }
                if state.phase == .focus && goal {
                    small("Take a break", .porkBonus, filled: true) { model.send(.takeBreak) }
                }
                if state.phase == .break {
                    small("Back to focus now") { model.send(.release) }
                }
                if state.phase != .idle {
                    Button("Stop") { model.send(.stop) }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                }
            }
        }
    }

    private func minutes(_ title: String, _ key: WritableKeyPath<PorkSettings, Int>, _ range: ClosedRange<Int>) -> some View {
        let value = state.settings[keyPath: key]
        return Stepper(value: Binding(
            get: { value },
            set: { v in model.updateSettings { $0[keyPath: key] = v } }
        ), in: range) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text("\(value) min").font(.headline).monospacedDigit()
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func big(_ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .controlSize(.large)
    }

    private func small(_ title: String, _ color: Color = .gray, filled: Bool = false,
                       action: @escaping () -> Void) -> some View {
        Group {
            if filled {
                Button(title, action: action).buttonStyle(.borderedProminent)
            } else {
                Button(title, action: action).buttonStyle(.bordered)
            }
        }
        .tint(color)
    }
}
