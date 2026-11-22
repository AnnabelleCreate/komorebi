import SwiftUI

struct StoryCover: View {
    var story: Story
    var body: some View {
        Image(story.coverImageName)
            .resizable()
            .aspectRatio(200.0 / 290.0, contentMode: .fit)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 3, bottomTrailingRadius: 8, topTrailingRadius: 8))
            .shadow(color: .black.opacity(0.45), radius: 14, y: 12)
            .accessibilityHidden(true)
    }
}

/// A story's page: cover, what it's about, and Read or Listen.
struct BookDetailView: View {
    var story: Story
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        let progress = store.state.progress[story.id]
        let listened = store.state.audioPositions[story.id] ?? 0
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StoryCover(story: story)
                    .frame(width: 190)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: story.collectionName)
                    Text(story.title).font(KFont.title(28)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
                    Text("\(story.author) · \(story.origin)").font(KFont.body(16)).foregroundStyle(Palette.text2)
                }
                HStack(spacing: 8) {
                    ActivityTag(text: "\(story.readMinutes) min read", systemImage: "book")
                    ActivityTag(text: "\(story.listenMinutes) min listen", systemImage: "headphones")
                }
                Text(story.synopsis).font(KFont.body(16)).foregroundStyle(Palette.text).lineSpacing(4)

                if let progress, progress.fraction > 0.02 {
                    ProgressView(value: progress.finished ? 1 : progress.fraction)
                        .tint(Palette.gold)
                        .accessibilityLabel(progress.finished ? "Finished" : "\(Int(progress.fraction * 100)) percent read")
                }

                HStack(spacing: 10) {
                    Button {
                        router.open(.reader(story.id))
                    } label: {
                        Label(readTitle(progress) == "Continue reading" ? "Continue" : readTitle(progress), systemImage: "book")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button {
                        router.open(.listen(story.id))
                    } label: {
                        Label(listened > 5 ? "Resume" : "Listen", systemImage: "headphones")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .labelStyle(.titleAndIcon)
                .padding(.top, 6)

                Text("Text from Project Gutenberg (eBook #\(story.gutenbergID)), from \(story.source). Narration by a LibriVox volunteer. Both are in the public domain.")
                    .font(KFont.body(14, relativeTo: .footnote))
                    .foregroundStyle(Palette.text3)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .kScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.toggleFavorite(story.id)
                    Haptics.shared.selection()
                } label: {
                    Image(systemName: store.isFavorite(story.id) ? "heart.fill" : "heart")
                        .foregroundStyle(Palette.text)
                }
                .accessibilityLabel(store.isFavorite(story.id) ? "Remove from favorites" : "Add to favorites")
            }
        }
    }

    private func readTitle(_ p: ReadingProgress?) -> String {
        guard let p else { return "Read" }
        if p.finished { return "Read again" }
        return p.fraction > 0.02 ? "Continue reading" : "Read"
    }
}
