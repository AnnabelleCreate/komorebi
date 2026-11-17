import Foundation

struct StoryBlock: Decodable, Hashable {
    enum Kind: String, Decodable { case paragraph, heading, poem }
    var type: Kind
    var text: String?
    var stanzas: [[String]]?
}

struct Story: Decodable, Identifiable, Hashable {
    var id: String
    var collection: String
    var title: String
    var origin: String
    var author: String
    var source: String
    var audioSeconds: Double
    var kind: String
    var synopsis: String
    var keepLine: String
    var palette: [String]
    var gutenbergID: Int
    var librivoxID: String
    var blocks: [StoryBlock]

    var coverImageName: String { "cover-\(id)" }
    var isPoems: Bool { kind == "poems" }

    var wordCount: Int {
        blocks.reduce(0) { total, block in
            let text = block.text ?? ""
            let poem = (block.stanzas ?? []).flatMap { $0 }.joined(separator: " ")
            return total + (text + " " + poem).split(whereSeparator: { $0 == " " || $0 == "\n" }).count
        }
    }

    var readMinutes: Int { max(2, Int((Double(wordCount) / (isPoems ? 130 : 200)).rounded())) }
    var listenMinutes: Int { max(1, Int((audioSeconds / 60).rounded())) }

    var collectionName: String { StoryLibrary.collectionName(collection) }

    static func == (lhs: Story, rhs: Story) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Loads the nine public-domain stories bundled with the app.
final class StoryLibrary {
    static let shared = StoryLibrary()

    let stories: [Story]
    let loadError: String?
    private let byID: [String: Story]

    struct StoryCollection: Identifiable { var id: String; var name: String }
    static let collections = [StoryCollection(id: "myth", name: "Mythology"), StoryCollection(id: "poems", name: "Poems"), StoryCollection(id: "lit", name: "Literature")]
    static func collectionName(_ id: String) -> String { collections.first { $0.id == id }?.name ?? "Stories" }

    private init() {
        var loaded: [Story] = []
        var problem: String?
        if let url = Bundle.main.url(forResource: "stories", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                loaded = try JSONDecoder().decode([Story].self, from: data)
            } catch {
                loaded = []
                problem = "The stories couldn't be opened. Try reinstalling Komorebi."
            }
        } else {
            problem = "The stories are missing from this build."
        }
        stories = loaded
        loadError = problem
        byID = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
    }

    func story(_ id: String?) -> Story? {
        guard let id else { return nil }
        return byID[id]
    }

    func stories(in collection: String) -> [Story] { stories.filter { $0.collection == collection } }

    /// Finds a bundled file whether Xcode copied it into a subfolder or flattened it.
    static func bundledURL(_ name: String, ext: String, folder: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext)
            ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: folder)
            ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources/\(folder)")
    }

    func audioURL(for story: Story) -> URL? {
        StoryLibrary.bundledURL(story.id, ext: "mp3", folder: "audio")
    }
}
