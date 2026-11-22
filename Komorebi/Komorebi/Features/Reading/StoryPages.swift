import NaturalLanguage
import UIKit

/// A story broken into sentences ("units"), grouped into paragraphs and stanzas,
/// so pages can be laid out and the narrated sentence can be highlighted.
struct StoryText {
    struct Unit {
        var text: String
        var paragraph: Int
    }

    enum ParagraphKind { case prose, heading, stanza }

    struct Paragraph {
        var kind: ParagraphKind
        var units: Range<Int>
        /// Poem number shown above the first stanza of a poem.
        var label: String?
    }

    let units: [Unit]
    let paragraphs: [Paragraph]
    /// Running character count at the start of each unit, used to estimate narration timing.
    private let charStarts: [Int]
    private let totalChars: Int

    init(story: Story) {
        var units: [Unit] = []
        var paragraphs: [Paragraph] = []
        func add(_ texts: [String], kind: ParagraphKind, label: String? = nil) {
            let start = units.count
            for t in texts where !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                units.append(Unit(text: t, paragraph: paragraphs.count))
            }
            if units.count > start { paragraphs.append(Paragraph(kind: kind, units: start..<units.count, label: label)) }
        }
        for block in story.blocks {
            switch block.type {
            case .heading:
                add([block.text ?? ""], kind: .heading)
            case .paragraph:
                add(StoryText.sentences(block.text ?? ""), kind: .prose)
            case .poem:
                for (i, stanza) in (block.stanzas ?? []).enumerated() {
                    add(stanza, kind: .stanza, label: i == 0 ? block.text : nil)
                }
            }
        }
        self.units = units
        self.paragraphs = paragraphs
        var starts: [Int] = []
        var total = 0
        for u in units { starts.append(total); total += max(1, u.text.count) }
        charStarts = starts
        totalChars = max(1, total)
    }

    static func sentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var out: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            out.append(text[range].trimmingCharacters(in: .whitespacesAndNewlines))
            return true
        }
        return out.isEmpty ? [text] : out
    }

    // MARK: Narration timing

    /// LibriVox recordings open with a short spoken introduction and end with a short closing.
    /// Timing inside the story is estimated from sentence length, so it can drift by a few seconds.
    static let introSeconds: Double = 18
    static let outroSeconds: Double = 10

    private func spokenSpan(_ duration: Double) -> (start: Double, length: Double) {
        let start = min(StoryText.introSeconds, duration * 0.1)
        let length = max(1, duration - start - min(StoryText.outroSeconds, duration * 0.05))
        return (start, length)
    }

    func time(ofUnit index: Int, duration: Double) -> Double {
        guard !units.isEmpty else { return 0 }
        let span = spokenSpan(duration)
        let i = max(0, min(units.count - 1, index))
        return span.start + span.length * Double(charStarts[i]) / Double(totalChars)
    }

    func unit(at seconds: Double, duration: Double) -> Int {
        guard !units.isEmpty else { return 0 }
        let span = spokenSpan(duration)
        let target = Int((seconds - span.start) / span.length * Double(totalChars))
        if target <= 0 { return 0 }
        var lo = 0, hi = units.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if charStarts[mid] <= target { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }

    /// Minutes of reading left from a unit, at about 200 words a minute.
    func minutesLeft(from unit: Int) -> Int {
        let remaining = units.suffix(from: max(0, min(units.count, unit))).reduce(0) { $0 + $1.text.split(separator: " ").count }
        return max(1, Int((Double(remaining) / 200).rounded(.up)))
    }
}

/// One page: a list of paragraph slices.
struct StoryPage {
    struct Slice {
        var paragraph: Int
        var units: Range<Int>
    }
    var slices: [Slice]
    var firstUnit: Int { slices.first?.units.lowerBound ?? 0 }
    var lastUnit: Int { (slices.last?.units.upperBound ?? 1) - 1 }
    func contains(unit: Int) -> Bool { unit >= firstUnit && unit <= lastUnit }
}

/// Lays a story out into pages that fit the reader at the chosen size and typeface.
enum StoryPaginator {
    static func paragraphSpacing(_ size: Double) -> CGFloat { CGFloat(size * 0.9) }
    static func lineSpacing(_ size: Double) -> CGFloat { CGFloat(size * 0.45) }

    static func text(for slice: StoryPage.Slice, in story: StoryText) -> String {
        let kind = story.paragraphs[slice.paragraph].kind
        return story.units[slice.units].map(\.text).joined(separator: kind == .stanza ? "\n" : " ")
    }

    static func pages(for story: StoryText, size: Double, serif: Bool, pageSize: CGSize) -> [StoryPage] {
        guard pageSize.width > 40, pageSize.height > 80, !story.units.isEmpty else {
            return [StoryPage(slices: story.paragraphs.indices.map { StoryPage.Slice(paragraph: $0, units: story.paragraphs[$0].units) })]
        }
        let bodyFont = KFont.readingUIFont(CGFloat(size), serif: serif)
        let headingFont = UIFont(name: "Urbanist-Bold", size: UIFontMetrics(forTextStyle: .body).scaledValue(for: CGFloat(size) + 2))
            ?? UIFont.boldSystemFont(ofSize: CGFloat(size) + 2)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing(size)
        // A little room for differences between UIKit and SwiftUI text layout.
        let available = pageSize.height * 0.94
        let gap = paragraphSpacing(size)

        func height(_ slice: StoryPage.Slice) -> CGFloat {
            let p = story.paragraphs[slice.paragraph]
            var string = text(for: slice, in: story)
            if p.label != nil && slice.units.lowerBound == p.units.lowerBound { string = (p.label ?? "") + "\n" + string }
            let font = p.kind == .heading ? headingFont : bodyFont
            let rect = (string as NSString).boundingRect(
                with: CGSize(width: pageSize.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .paragraphStyle: style], context: nil)
            return ceil(rect.height) + (p.kind == .heading ? 12 : 0)
        }

        var pages: [StoryPage] = []
        var current: [StoryPage.Slice] = []
        var used: CGFloat = 0

        for (pi, paragraph) in story.paragraphs.enumerated() {
            var start = paragraph.units.lowerBound
            while start < paragraph.units.upperBound {
                let spacing = current.isEmpty ? 0 : gap
                let whole = StoryPage.Slice(paragraph: pi, units: start..<paragraph.units.upperBound)
                let h = height(whole)
                // Keep a heading with what follows it.
                let isHeading = paragraph.kind == .heading
                if used + spacing + h <= available && !(isHeading && used + spacing + h > available * 0.85) {
                    current.append(whole)
                    used += spacing + h
                    break
                }
                // Fit as many sentences as possible on this page.
                var fit = 0
                if !isHeading {
                    var count = 1
                    while start + count <= paragraph.units.upperBound {
                        let slice = StoryPage.Slice(paragraph: pi, units: start..<(start + count))
                        if used + spacing + height(slice) <= available { fit = count; count += 1 } else { break }
                    }
                }
                if fit > 0 {
                    current.append(StoryPage.Slice(paragraph: pi, units: start..<(start + fit)))
                    start += fit
                }
                if current.isEmpty {
                    // A single sentence taller than the page: give it a page of its own.
                    current.append(StoryPage.Slice(paragraph: pi, units: start..<(start + 1)))
                    start += 1
                }
                pages.append(StoryPage(slices: current))
                current = []
                used = 0
            }
        }
        if !current.isEmpty { pages.append(StoryPage(slices: current)) }
        return pages
    }
}
