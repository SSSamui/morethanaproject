// Stops the focus clock while the phone is locked, and starts it again when
// you unlock. iPhone apps aren't told about locking while they sleep in the
// background, so during focus Pork keeps the app awake with silent audio
// (mixed with your music, nothing you can hear). Needs a passcode or Face ID.
// Setting: "Pause the clock when the phone locks".

import AVFoundation
import UIKit

@MainActor
final class LockWatcher {
    static let shared = LockWatcher()

    private var player: AVAudioPlayer?
    private var observing = false
    private let defaults = PorkStore.defaults

    /// The clock was paused because the phone locked.
    var pausedByLock: Bool {
        get { defaults.bool(forKey: "pausedByLock") }
        set { defaults.set(newValue, forKey: "pausedByLock") }
    }

    /// Call after every change: keeps the app awake only while a focus
    /// session runs (or is paused by the lock).
    func update(_ s: PorkState) {
        observe()
        let wanted = s.settings.pauseOnLock && s.phase == .focus && (!s.paused || pausedByLock)
        if !wanted && s.phase != .focus { pausedByLock = false }
        wanted ? keepAwake() : sleep()
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
        let s = PorkStore.load()
        guard s.settings.pauseOnLock, s.phase == .focus, !s.paused else { return }
        pausedByLock = true
        AppModel.shared.send(.pause)
    }

    private func unlocked() {
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
