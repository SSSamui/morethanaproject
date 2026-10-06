// Pork scratching the glass door (plays while he's up on his back legs).

import AVFoundation

@MainActor
final class ScratchPlayer {
    static let shared = ScratchPlayer()
    private var player: AVAudioPlayer?

    func set(_ on: Bool) {
        if !on {
            player?.stop()
            return
        }
        if player == nil, let url = Bundle.main.url(forResource: "scratch", withExtension: "wav") {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            player = try? AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = 0.6
        }
        if player?.isPlaying == false { player?.play() }
    }
}
