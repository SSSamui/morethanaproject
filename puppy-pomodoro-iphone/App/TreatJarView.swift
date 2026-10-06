// Pork's treat jar. Tap a treat to see when it was earned.

import SwiftUI

struct TreatJarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var picked: Treat?

    var body: some View {
        let treats = model.state.treats
        VStack(spacing: 0) {
            HStack {
                Text("🫙 Pork's treats").font(.headline)
                Spacer()
                Text(treats.isEmpty ? "no treats yet" : "\(treats.count) treat\(treats.count > 1 ? "s" : "")")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))

            Group {
                if treats.isEmpty {
                    Text("Finish a focus session to give Pork a treat. Extra focus = bonus treats!")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .padding(.horizontal, 12)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 34), spacing: 2)], spacing: 2) {
                                ForEach(treats) { t in
                                    Text(t.t)
                                        .font(.system(size: 28))
                                        .scaleEffect(picked == t ? 1.3 : 1)
                                        .id(t.id)
                                        .transition(.scale(scale: 0.01).combined(with: .opacity))
                                        .onTapGesture { picked = picked == t ? nil : t }
                                        .accessibilityLabel(describe(t))
                                }
                            }
                            .padding(8)
                        }
                        .frame(maxHeight: 170)
                        .onAppear { if let id = treats.last?.id { proxy.scrollTo(id, anchor: .bottom) } }
                        .onChange(of: treats.count) { _, _ in
                            if let id = treats.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                        }
                    }
                }
            }
            .background(Color(red: 0.984, green: 0.914, blue: 0.784).opacity(0.85))

            if let picked {
                Text("\(picked.t) \(describe(picked))")
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(.secondarySystemGroupedBackground))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 0.5))
    }

    private func describe(_ t: Treat) -> String {
        let when = t.at.formatted(date: .abbreviated, time: .shortened)
        return "\(when) · \(t.bonus ? "bonus for extra focus" : "focus goal")"
    }
}
