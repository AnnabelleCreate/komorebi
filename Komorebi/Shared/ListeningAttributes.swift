import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Live Activity shown while a story is being narrated (with an optional sleep timer).
struct ListeningAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isPlaying: Bool
        /// When the sleep timer will fade the story out, if one is set.
        var sleepEndsAt: Date?
        /// Seconds into the story when this state was sent.
        var elapsed: Double
        var duration: Double
    }

    var storyID: String
    var title: String
    var author: String
}
#endif
