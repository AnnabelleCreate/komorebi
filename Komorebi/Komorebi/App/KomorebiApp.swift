import SwiftUI
import UserNotifications

@main
struct KomorebiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = AppStore.shared
    @State private var router = Router.shared
    @State private var narration = NarrationPlayer.shared
    @State private var prompts = PromptScheduler.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FontRegistrar.registerBundledFonts()
        SoundEngine.shared.prepare()
        Appearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .environment(narration)
                .environment(prompts)
                .preferredColorScheme(.dark)
                .onOpenURL { router.handle(url: $0) }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                store.saveNow()
            case .active:
                prompts.refreshAuthorizationStatus()
                store.publishWidgetSnapshot()
            @unknown default:
                break
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let link = response.notification.request.content.userInfo["link"] as? String, let url = URL(string: link) {
            DispatchQueue.main.async { Router.shared.handle(url: url) }
        }
        completionHandler()
    }
}

/// UIKit appearance for the tab bar and navigation bars.
enum Appearance {
    static func configure() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(Palette.card)
        tab.shadowColor = UIColor(Palette.outline)
        let item = tab.stackedLayoutAppearance
        item.normal.iconColor = UIColor(Palette.text3)
        item.normal.titleTextAttributes = [.foregroundColor: UIColor(Palette.text3)]
        item.selected.iconColor = UIColor(Palette.gold)
        item.selected.titleTextAttributes = [.foregroundColor: UIColor(Palette.text)]
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.titleTextAttributes = [.foregroundColor: UIColor(Palette.text)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(Palette.text)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(Palette.gold)
    }
}
