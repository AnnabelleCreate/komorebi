import Observation
import SwiftUI

enum AppTab: Hashable { case tonight, discover, kits, profile }

/// Full-screen activities that sit above the tabs.
enum ActivityRoute: Identifiable, Hashable {
    case garden
    case lantern
    case reader(String)
    case listen(String)

    var id: String {
        switch self {
        case .garden: return "garden"
        case .lantern: return "lantern"
        case .reader(let storyID): return "read-\(storyID)"
        case .listen(let storyID): return "listen-\(storyID)"
        }
    }
}

@Observable
final class Router {
    static let shared = Router()
    var tab: AppTab = .tonight
    var activity: ActivityRoute?
    /// Set when a link asks the Kits tab to show the order list.
    var showOrders = false

    private init() {}

    func open(_ route: ActivityRoute) {
        Haptics.shared.tap()
        activity = route
    }

    func handle(url: URL) {
        guard url.scheme == KomorebiShared.urlScheme else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        let library = StoryLibrary.shared
        switch url.host ?? "" {
        case "garden": activity = .garden
        case "lantern": activity = .lantern
        case "read":
            if let id = parts.first, library.story(id) != nil { activity = .reader(id) } else { activity = nil; tab = .discover }
        case "listen":
            if let id = parts.first, library.story(id) != nil { activity = .listen(id) } else { activity = nil; tab = .discover }
        case "kits":
            activity = nil
            tab = .kits
        default:
            activity = nil
            tab = .tonight
        }
    }
}
