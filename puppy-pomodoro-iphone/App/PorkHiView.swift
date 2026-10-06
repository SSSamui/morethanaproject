// "Pork says hi": before you use your phone, Pork's photos and videos from an
// album in Photos play for a minute (or the time you chose). Then you decide
// whether to continue.

import AVFoundation
import Photos
import SwiftUI

struct PorkHiView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var show = AlbumShow()
    @State private var started = Date()
    @State private var asking = false
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        let st = model.state.settings
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                switch show.current {
                case .photo(let image):
                    Image(uiImage: image).resizable().scaledToFit()
                        .id(show.counter)
                        .transition(.opacity)
                case .video(let player):
                    PlayerView(player: player)
                        .id(show.counter)
                        .transition(.opacity)
                case nil:
                    ProgressView().tint(.white)
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: show.counter)
            .opacity(asking ? 0.35 : 1)

            VStack {
                HStack {
                    Text("Pork says hi 🐾").font(.headline)
                    Spacer()
                    if !asking {
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            let left = max(0, TimeInterval(st.hiSeconds) - ctx.date.timeIntervalSince(started))
                            Text(PorkClock.text(left + 0.999)).monospacedDigit().font(.headline)
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(.black.opacity(0.35), in: Capsule())
                .padding(.horizontal, 16)

                Spacer()

                if let message = show.message, !asking {
                    Text(message)
                        .font(.footnote).foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                }

                if asking { question }
            }
            .padding(.vertical, 12)
        }
        .statusBarHidden()
        .onAppear {
            started = Date()
            show.start(album: st.hiAlbum, muted: st.hiMuted)
        }
        .onDisappear { show.stop() }
        .onReceive(ticker) { now in
            show.tick(now)
            if !asking, now.timeIntervalSince(started) >= TimeInterval(st.hiSeconds) {
                withAnimation(.spring) { asking = true }
            }
        }
    }

    private var question: some View {
        VStack(spacing: 12) {
            Image("PorkWait").resizable().scaledToFit().frame(height: 70)
            Text("Do you want to keep using your phone?")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Button {
                model.allowPhoneForAWhile()
                dismiss()
                model.show("Swipe right along the bottom edge to go back to your app ↩︎")
            } label: {
                Text("Yes, continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(.gray).controlSize(.large)

            Button {
                dismiss()
                model.send(.start(nil))
            } label: {
                Text("▶ Start focus with Pork").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(.porkFocus).controlSize(.large)

            Button {
                dismiss()
                model.show("Good choice! Pork is proud of you 🐾")
            } label: {
                Text("No, I'll put my phone down").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).controlSize(.large)

            Button("Keep watching Pork") {
                withAnimation { asking = false }
                started = Date()
            }
            .font(.footnote)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Plays the album: photos for 5 seconds each, videos to the end.
final class AlbumShow: ObservableObject {
    enum Item {
        case photo(UIImage)
        case video(AVPlayer)
    }

    @Published var current: Item?
    @Published var message: String?
    @Published var counter = 0

    private var assets: [PHAsset] = []
    private var drawings = ["RoomWait", "RoomPace", "RoomDoor", "RoomSleep"]
    private var index = 0
    private var request = 0 // ignore late answers for an earlier photo/video
    private var shownAt = Date()
    private var muted = false
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private let photoSeconds: TimeInterval = 5

    func start(album: String, muted: Bool) {
        self.muted = muted
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    self.useDrawings("Allow Photos in Settings → Puppy Pomodoro → Photos so Pork's photos and videos can play here.")
                    return
                }
                self.assets = Self.fetch(album).shuffled()
                if self.assets.isEmpty {
                    self.useDrawings("Make an album called “\(album)” in Photos and put Pork's photos and videos in it.")
                } else {
                    self.showCurrent()
                }
            }
        }
    }

    func stop() {
        player?.pause()
        player = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
    }

    func tick(_ now: Date) {
        if case .photo = current, now.timeIntervalSince(shownAt) >= photoSeconds { next() }
    }

    private func next() {
        let count = assets.isEmpty ? drawings.count : assets.count
        index = (index + 1) % max(1, count)
        if assets.isEmpty { showDrawing() } else { showCurrent() }
    }

    private func useDrawings(_ text: String) {
        message = text
        showDrawing()
    }

    private func showDrawing() {
        shownAt = Date()
        if let image = UIImage(named: drawings[index % drawings.count]) { set(.photo(image)) }
    }

    private func set(_ item: Item) {
        current = item
        counter += 1
    }

    private func showCurrent() {
        stop()
        let asset = assets[index]
        shownAt = Date()
        request += 1
        let mine = request
        if asset.mediaType == .video {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { item, _ in
                DispatchQueue.main.async {
                    guard self.request == mine else { return }
                    guard let item else { self.next(); return }
                    let player = AVPlayer(playerItem: item)
                    player.isMuted = self.muted
                    self.endObserver = NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
                    ) { [weak self] _ in self?.next() }
                    self.player = player
                    self.set(.video(player))
                    player.play()
                }
            }
        } else {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 1600, height: 1600),
                                                  contentMode: .aspectFit, options: options) { image, _ in
                DispatchQueue.main.async {
                    guard self.request == mine else { return }
                    if let image { self.set(.photo(image)) } else { self.next() }
                }
            }
        }
    }

    private static func fetch(_ title: String) -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", title)
        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
        guard let album = albums.firstObject else { return [] }
        var out: [PHAsset] = []
        PHAsset.fetchAssets(in: album, options: nil).enumerateObjects { asset, _, _ in
            if asset.mediaType == .image || asset.mediaType == .video { out.append(asset) }
        }
        return out
    }
}

/// A video without playback controls.
struct PlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ view: PlayerUIView, context: Context) {
        view.playerLayer.player = player
    }

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
