import SwiftUI

struct ProfileView: View {
    enum Segment: Hashable { case favorites, purchases }
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @State private var segment: Segment = .favorites

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 12) {
                        Circle()
                            .fill(Palette.text)
                            .frame(width: 100, height: 100)
                            .overlay {
                                if let initial = store.state.name.first {
                                    Text(String(initial).uppercased()).font(KFont.title(40)).foregroundStyle(Palette.card)
                                } else {
                                    Image(systemName: "person").font(.system(size: 40, weight: .light)).foregroundStyle(Color(hex: 0x8A7F6C))
                                }
                            }
                            .accessibilityHidden(true)
                        Text(store.state.name.isEmpty ? "Welcome" : "Welcome \(store.state.name)")
                            .font(KFont.title(32, relativeTo: .largeTitle))
                            .foregroundStyle(Palette.text)
                            .accessibilityAddTraits(.isHeader)
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape").font(.system(size: 22)).foregroundStyle(Palette.text).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Settings")
                }
                .padding(.top, 12)

                PillPicker(options: [(Segment.favorites, "Favorited Activities"), (Segment.purchases, "Purchase History")],
                           selection: $segment, label: "Profile sections")
                    .padding(3)
                    .background(Capsule().fill(Palette.cardRaised))
                    .overlay(Capsule().strokeBorder(Palette.outline))

                if segment == .favorites { favorites } else { purchases }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .kScreen()
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder private var favorites: some View {
        let items = store.state.favorites.compactMap(ActivityItem.from(key:))
        if items.isEmpty {
            EmptyState(systemImage: "heart", title: "No favorites yet",
                       message: "Tap the heart on any activity or story to keep it here.",
                       actionTitle: "Browse activities") { router.tab = .discover }
        } else {
            VStack(spacing: 10) {
                ForEach(items) { item in FavoriteCard(item: item) }
            }
        }
    }

    @ViewBuilder private var purchases: some View {
        if store.state.orders.isEmpty {
            EmptyState(systemImage: "shippingbox", title: "No purchases yet",
                       message: "Kits you order show up here. You can turn a monthly plan off anytime.",
                       actionTitle: "See this month’s kit") { router.tab = .kits }
        } else {
            VStack(spacing: 10) {
                ForEach(store.state.orders) { order in PurchaseCard(order: order) }
                Text("Beta: purchases are saved on this phone. Payments ran in test mode.")
                    .font(KFont.body(12)).foregroundStyle(Palette.text3).frame(maxWidth: .infinity)
            }
        }
    }
}

struct FavoriteCard: View {
    var item: ActivityItem
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ArtImage(name: item.artName).frame(width: 80, height: 109).clipped()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(item.tags.indices, id: \.self) { i in
                        ActivityTag(text: item.tags[i].0, systemImage: item.tags[i].1, filled: item.tags[i].2)
                    }
                }
                Text(item.title).font(KFont.title(19)).foregroundStyle(Palette.text)
                Text(item.subtitle).font(KFont.body(15)).foregroundStyle(Palette.text2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 28)
        }
        .padding(16)
        .kCard()
        .contentShape(Rectangle())
        .onTapGesture { item.open(router: router) }
        .overlay(alignment: .topTrailing) {
            Button {
                store.toggleFavorite(item.id)
                Haptics.shared.selection()
            } label: {
                Image(systemName: "heart.fill").font(.system(size: 20)).foregroundStyle(Palette.text).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(6)
            .accessibilityLabel("Remove \(item.title) from favorites")
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open \(item.title)") { item.open(router: router) }
    }
}

struct PurchaseCard: View {
    var order: KitOrder
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @State private var confirmCancel = false

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ArtImage(name: "art-kit").frame(width: 80, height: 109).clipped()
            VStack(alignment: .leading, spacing: 3) {
                Text(order.plan == .monthly ? "Komorebi Monthly Kit" : "Komorebi Kit")
                    .font(KFont.title(19)).foregroundStyle(Palette.text).padding(.trailing, 30)
                Text("Purchased on \(order.placedAt.formatted(.dateTime.month(.defaultDigits).day()))")
                    .font(KFont.body(15)).foregroundStyle(Palette.text)
                if order.plan == .monthly {
                    Toggle(isOn: Binding(get: { order.isActive }, set: { on in
                        if on { setActive(true) } else { confirmCancel = true }
                    })) {
                        Text("Monthly Subscription").font(KFont.body(15)).foregroundStyle(Palette.text)
                    }
                    .tint(Palette.gold)
                } else {
                    Text("One-time box").font(KFont.body(15)).foregroundStyle(Palette.text2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .kCard()
        .overlay(alignment: .topTrailing) {
            Button {
                router.tab = .kits
                router.showOrders = true
            } label: {
                Image(systemName: "pencil").font(.system(size: 16)).foregroundStyle(Palette.text).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel("Manage order \(order.number)")
        }
        .confirmationDialog("Cancel your monthly kit?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Cancel monthly plan", role: .destructive) { setActive(false) }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("No more boxes and no more charges.")
        }
    }

    private func setActive(_ on: Bool) {
        guard let i = store.state.orders.firstIndex(where: { $0.id == order.id }) else { return }
        store.state.orders[i].isActive = on
        if on { store.state.orders[i].skipNextBox = false }
        PromptScheduler.shared.scheduleKitReminders(for: store.state.orders)
        Haptics.shared.selection()
    }
}
