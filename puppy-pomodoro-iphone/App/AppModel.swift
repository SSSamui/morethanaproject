// What the screen shows. The timer itself lives in PorkStore (shared with the
// widgets and Screen Time extensions); this keeps a copy for SwiftUI.

import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var state = PorkStore.load()
    @Published var showHi = false
    @Published var toast: String?
    @Published var releasingUntil = Date.distantPast // door animation after "let Pork out"

    private var toastTask: Task<Void, Never>?

    func send(_ cmd: PorkCommand) {
        if case .release = cmd { releasingUntil = Date().addingTimeInterval(3.2) }
        setState(PorkCommands.run(cmd))
    }

    func reload() {
        var s = PorkStore.load()
        s.advance()
        setState(s)
    }

    func becameActive() {
        let s = PorkCommands.run(.sync)
        PorkCommands.apply(s) // also catches up after changes made from the blocked-app screen
        #if !LITE
        ScreenTime.scheduleNight(s.settings)
        #endif
        setState(s)
        Task { await LiveActivities.update(s) }
        Alerts.requestPermission()
    }

    func updateSettings(_ change: (inout PorkSettings) -> Void) {
        var st = state.settings
        change(&st)
        guard st != state.settings else { return }
        send(.settings(st))
    }

    /// "Yes, continue": Pork won't say hi again for a while.
    func allowPhoneForAWhile() {
        var s = PorkStore.load()
        s.hiAllowedUntil = Date().addingTimeInterval(TimeInterval(s.settings.hiGraceMin * 60))
        PorkStore.save(s)
        state = s
    }

    func show(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled { toast = nil }
        }
    }

    private func setState(_ s: PorkState) {
        let prev = state
        // Back to focus from the break: play the door animation.
        if (prev.phase == .break || prev.phase == .overtime) && s.phase == .focus {
            releasingUntil = max(releasingUntil, Date().addingTimeInterval(3.2))
        }
        if let r = s.lastReward, r != prev.lastReward, Date().timeIntervalSince(r.at) < 15 {
            show(s.phase == .break ? "Break time! Pork got \(r.items.joined()) 🐾" : "Pork got \(r.items.joined()) 🐾")
        }
        // New treats pop into the jar.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
            state = s
        }
    }
}

enum Gate {
    /// Should Pork show his photos before you use the phone?
    static func shouldSayHi(_ s: PorkState, now: Date = Date()) -> Bool {
        guard s.settings.hiEnabled, s.phase == .idle else { return false }
        return (s.hiAllowedUntil ?? .distantPast) <= now
    }
}
