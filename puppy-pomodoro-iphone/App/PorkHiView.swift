// Pork's check-in: the Calendar event on now (as a big sticky note), your
// to-dos as sticky notes, how often you opened distraction apps today, and
// Pork's photos. Opens from Pork's reminders, the Shortcuts automation, or
// "Try the check-in" in Settings.

import AVFoundation
import Photos
import SwiftUI

struct PorkHiView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var show = AlbumShow()
    @ObservedObject private var todos = TodoStore.shared
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        let st = model.state.settings
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if model.funFirst && !todos.snapshot.fun.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("🎈 Something fun instead?")
                                .font(.system(.title, design: .rounded).weight(.heavy))
                            Text("Pork picked these from your fun list. They're better than scrolling!")
                                .font(.subheadline).foregroundStyle(.secondary)
                            FunBoard(todos: todos)
                            Button("No thanks, go on") {
                                model.funFirst = false
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    if let event = todos.event {
                        BigEventNote(event: event)
                    }

                    StickyBoard(todos: todos)

                    if !model.funFirst {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("🎈 Fun list").font(.title3.bold())
                            FunBoard(todos: todos)
                        }
                    }

                    ScreenTimeCard()

                    usage

                    porkPhotos

                    VStack(spacing: 10) {
                        Button {
                            dismiss()
                            Nudges.focusOpened()
                            model.send(.start(nil))
                        } label: {
                            Text("▶ Start focus with Pork").font(.headline).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(.porkFocus).controlSize(.large)

                        Button {
                            dismiss()
                            model.show("Good choice! Pork is proud of you 🐾")
                        } label: {
                            Text("OK, back to my to-dos").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).controlSize(.large)
                    }
                }
                .padding(16)
            }
            .background(Color.porkWall.opacity(0.45).ignoresSafeArea())
            .navigationTitle("Pork's check-in 🐾")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Close")
                }
            }
        }
        .task { await todos.refresh() }
        .onAppear { show.start(album: st.hiAlbum, muted: st.hiMuted) }
        .onDisappear {
            show.stop()
            model.funFirst = false
        }
        .onReceive(ticker) { show.tick($0) }
    }

    private var usage: some View {
        let opens = Nudges.opensToday
        return HStack(spacing: 12) {
            Text("📱").font(.largeTitle)
            VStack(alignment: .leading, spacing: 2) {
                Text("Distraction apps today").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Text(opens == 0 ? "Not opened yet" : "Opened \(opens) time\(opens == 1 ? "" : "s")")
                    .font(.title3.bold())
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var porkPhotos: some View {
        ZStack {
            Color.black
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
            if let message = show.message {
                VStack {
                    Spacer()
                    Text(message).font(.caption).foregroundStyle(.white)
                        .padding(8).background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                        .padding(8)
                }
            }
        }
        .animation(.easeInOut(duration: 0.6), value: show.counter)
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topLeading) {
            Text("Pork says hi 🐾").font(.caption.bold()).foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.black.opacity(0.4), in: Capsule())
                .padding(10)
        }
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
