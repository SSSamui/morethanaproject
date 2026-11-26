// The diary box: what you see when Pork asks (the unlock check), or when you
// tap "+ Write" in the diary. The keyboard is ready right away; anything
// counts, even "ok". Then one of Pork's photos as a thank-you, and your apps
// open.

import Photos
import SwiftUI
import UIKit

struct WriteView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var mood: String?
    @State private var photo: UIImage?
    @State private var showCamera = false
    @State private var savedAt: Date?
    @State private var reward: UIImage?
    @State private var appeared = Date()
    @State private var prompt = DiaryLevel.prompt(Int(Date().timeIntervalSince1970 / 60))
    @FocusState private var typing: Bool

    private var level: Int { Gate.settings.level }
    private var started: Date { Gate.startedAt ?? appeared }
    private var canSave: Bool {
        if level == 1 && photo != nil { return true }
        if level == 3 && mood == nil { return false }
        return DiaryLevel.isEnough(text, level: level)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let savedAt { thanks(savedAt) } else { form }
            }
            .background(Color.porkWall.ignoresSafeArea())
            .environment(\.colorScheme, .light)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if savedAt == nil {
                        Button("Not now") { notNow() }.foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if savedAt == nil {
                        Button("Save 🐾") { save() }.bold().disabled(!canSave)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $photo).ignoresSafeArea()
        }
        .onAppear {
            appeared = Date()
            typing = true
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image("PorkWait").resizable().scaledToFit().frame(width: 74, height: 60)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hi! 🐾").font(.title2.bold())
                        Text("\(started.formatted(.dateTime.weekday(.wide).month().day())) · \(Dur.clock(started))")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Text(prompt).font(.title3.weight(.semibold))

                if level == 3 {
                    Text("How do you feel?").font(.subheadline.weight(.semibold))
                    FlowChips(items: DiaryLevel.feelings, selected: $mood)
                }

                if let photo {
                    Image(uiImage: photo).resizable().scaledToFit()
                        .frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topTrailing) {
                            Button { self.photo = nil } label: {
                                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(Color.white, Color.black.opacity(0.5))
                            }
                            .padding(6)
                        }
                }

                TextField(level == 4 ? "A few sentences…" : "One sentence…", text: $text, axis: .vertical)
                    .lineLimit(level == 4 ? 4...10 : 2...6)
                    .font(.body)
                    .padding(12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    .focused($typing)
                    .submitLabel(.done)

                if level == 4 {
                    let n = DiaryLevel.words(text)
                    Text("\(n) / \(DiaryLevel.paragraphWords) words")
                        .font(.caption).foregroundStyle(n >= DiaryLevel.paragraphWords ? Color.porkFocus : .secondary)
                }

                HStack {
                    if level == 1 && UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { typing = false; showCamera = true } label: {
                            Label(photo == nil ? "Take a photo instead" : "Take another", systemImage: "camera.fill")
                        }
                        .buttonStyle(.bordered).tint(.porkFocus)
                    }
                    Spacer()
                    Button { prompt = DiaryLevel.prompt(Int.random(in: 0...999)) } label: {
                        Label("Another question", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .font(.footnote).buttonStyle(.borderless)
                }

                Button { save() } label: {
                    Text("Save 🐾").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent).tint(.porkFocus).controlSize(.large)
                .disabled(!canSave)

                Text("Anything counts. It goes in your diary with the time.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20)
            .foregroundStyle(Color(red: 0.13, green: 0.10, blue: 0.08))
        }
    }

    private func thanks(_ at: Date) -> some View {
        VStack(spacing: 16) {
            Spacer()
            if let reward {
                Image(uiImage: reward).resizable().scaledToFit()
                    .frame(maxHeight: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 6)
            } else {
                Image("PorkSleep").resizable().scaledToFit().frame(maxHeight: 200)
            }
            Text("Saved at \(Dur.clock(at)) ✓").font(.title2.bold())
            Text(Gate.settings.on ? "Your apps are open. Pork says thank you 🐾" : "Pork says thank you 🐾")
                .font(.headline).foregroundStyle(.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent).tint(.porkFocus).controlSize(.large)
            Spacer()
        }
        .padding(24)
        .foregroundStyle(Color(red: 0.13, green: 0.10, blue: 0.08))
        .task {
            reward = await PorkPhotos.random(album: model.state.settings.hiAlbum)
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            dismiss()
        }
    }

    private func save() {
        guard canSave else { return }
        let now = Date()
        var entry = DiaryEntry(started: started, saved: now, kind: photo == nil ? .text : .photo,
                               text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                               mood: level == 3 ? mood : nil, prompt: prompt, level: level)
        if let photo, let jpeg = photo.shrunk(to: 1600).jpegData(compressionQuality: 0.75) {
            entry.photo = Diary.savePhoto(jpeg, at: started)
        }
        Diary.add(entry)
        if Gate.settings.on { Gate.open(now) } else { Gate.startedAt = nil }
        model.gatePassed()
        typing = false
        withAnimation { savedAt = now }
    }

    private func notNow() {
        if Gate.settings.on { Gate.notNow() } else { Gate.startedAt = nil }
        model.gatePassed()
        dismiss()
    }
}

/// Feeling buttons that wrap onto more lines.
struct FlowChips: View {
    let items: [String]
    @Binding var selected: String?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button { selected = item } label: {
                    Text(item).font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(selected == item ? Color.porkFocus : Color.white, in: Capsule())
                        .foregroundStyle(selected == item ? Color.white : Color.black)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The iPhone camera (photos from the library don't count: it's a real moment).
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

extension UIImage {
    /// The same picture, at most `side` points on its longest side.
    func shrunk(to side: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > side else { return self }
        let scale = side / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

/// One of Pork's photos from the album picked in Settings.
enum PorkPhotos {
    static func random(album: String) async -> UIImage? {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard status == .authorized || status == .limited else { return nil }
        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var found: PHAssetCollection?
        albums.enumerateObjects { c, _, stop in
            if c.localizedTitle == album { found = c; stop.pointee = true }
        }
        guard let found else { return nil }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let assets = PHAsset.fetchAssets(in: found, options: options)
        guard assets.count > 0 else { return nil }
        let asset = assets.object(at: Int.random(in: 0..<assets.count))
        let request = PHImageRequestOptions()
        request.deliveryMode = .highQualityFormat
        request.isNetworkAccessAllowed = true
        return await withCheckedContinuation { done in
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 900, height: 900),
                                                  contentMode: .aspectFit, options: request) { image, _ in
                done.resume(returning: image)
            }
        }
    }
}
