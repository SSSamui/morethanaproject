// Notices when the phone locks. iPhone apps aren't told about locking while
// they sleep in the background, so Pork keeps the app awake with silent
// audio (mixed with your music, nothing you can hear). Needs a passcode or
// Face ID. Two jobs:
// - unlock check: after you write, Pork waits for the lock; locked for more
//   than the grace time (1 min) → the check comes back for the next app.
// - focus clock: stops while the phone is locked ("Pause the clock when the
//   phone locks").
// If iOS closes Pork anyway, the 20-minute backup check still works.

import AVFoundation
import UIKit

@MainActor
final class LockWatcher {
    static let shared = LockWatcher()

    private var player: AVAudioPlayer?
    private var observing = false
    private var rearm: Task<Void, Never>?
    private let defaults = PorkStore.defaults

    /// The clock was paused because the phone locked.
    var pausedByLock: Bool {
        get { defaults.bool(forKey: "pausedByLock") }
        set { defaults.set(newValue, forKey: "pausedByLock") }
    }

    /// The unlock check is waiting for the phone to lock.
    private var watchingGate: Bool {
        let g = Gate.settings
        return g.on && g.watchLock && ScreenTime.isOn && Gate.isOpen() && !Gate.skippedToday
    }

    /// Call after every change: keeps the app awake only while needed.
    func update(_ s: PorkState) {
        observe()
        let clock = s.settings.pauseOnLock && s.phase == .focus && (!s.paused || pausedByLock)
        if !clock && s.phase != .focus { pausedByLock = false }
        (clock || watchingGate || rearm != nil) ? keepAwake() : sleep()
    }

    private func observe() {
        guard !observing else { return }
        observing = true
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in LockWatcher.shared.locked() }
        }
        center.addObserver(forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in LockWatcher.shared.unlocked() }
        }
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { _ in
            // Another app took the audio; start again when it's done.
            Task { @MainActor in LockWatcher.shared.player?.play() }
        }
    }

    private func locked() {
        if watchingGate {
            let grace = UInt64(max(0, Gate.settings.graceSec))
            rearm?.cancel()
            rearm = Task { @MainActor in
                try? await Task.sleep(nanoseconds: grace * 1_000_000_000)
                guard !Task.isCancelled else { return }
                Gate.arm()          // the next app you open asks again
                LockWatcher.shared.rearm = nil
                LockWatcher.shared.update(PorkStore.load())
            }
        }
        let s = PorkStore.load()
        guard s.settings.pauseOnLock, s.phase == .focus, !s.paused else { return }
        pausedByLock = true
        AppModel.shared.send(.pause)
    }

    private func unlocked() {
        // Back within the grace time: no new check.
        rearm?.cancel()
        rearm = nil
        guard pausedByLock else { return }
        pausedByLock = false
        let s = PorkStore.load()
        if s.phase == .focus && s.paused { AppModel.shared.send(.resume) }
    }

    private func keepAwake() {
        if player == nil, let url = Bundle.main.url(forResource: "silence", withExtension: "wav") {
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            player = try? AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = 0.01
        }
        if player?.isPlaying == false { player?.play() }
    }

    private func sleep() {
        guard player != nil else { return }
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
