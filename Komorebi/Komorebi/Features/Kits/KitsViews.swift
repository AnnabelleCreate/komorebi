import SwiftUI

enum KitStep: Hashable { case detail, often, bag, shipping, payment, review, confirmed(UUID), orders }

/// Kits tab with its own navigation, so checkout steps stack and Back works naturally.
struct KitsTab: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @State private var path: [KitStep] = []
    @State private var checkout = CheckoutModel(saved: nil)

    var body: some View {
        NavigationStack(path: $path) {
            KitsHome(path: $path, startCheckout: startCheckout)
                .navigationDestination(for: KitStep.self) { step in
                    switch step {
                    case .detail: KitDetailView(path: $path, startCheckout: startCheckout)
                    case .often: HowOftenView(model: checkout, path: $path)
                    case .bag: BagView(model: checkout, path: $path)
                    case .shipping: ShippingView(model: checkout, path: $path)
                    case .payment: PaymentView(model: checkout, path: $path)
                    case .review: ReviewView(model: checkout, path: $path)
                    case .confirmed(let id): ConfirmedView(orderID: id, path: $path)
                    case .orders: OrdersView()
                    }
                }
        }
        .onChange(of: router.showOrders) { _, show in
            if show { path = [.orders]; router.showOrders = false }
        }
    }

    private func startCheckout() {
        checkout = CheckoutModel(saved: store.state.savedAddress)
        if let saved = store.state.savedAddress { checkout.cardName = saved.name }
        path.append(.often)
    }
}

/// Pins a checkout step's main button above the tab bar, so it never has to be scrolled to.
struct CheckoutActionBar<Action: View>: ViewModifier {
    @ViewBuilder var action: () -> Action
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) { action() }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                .background(Palette.background)
        }
    }
}

extension View {
    func checkoutAction<A: View>(@ViewBuilder _ action: @escaping () -> A) -> some View {
        modifier(CheckoutActionBar(action: action))
    }
}

struct KitContents: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            row("square.grid.3x3", "Sand tracing tray", "With a wooden stylus and three pattern cards")
            row("books.vertical", "Two short-story paperbacks", "From this month’s stories")
            row("circle.hexagongrid", "Three quiet fidget toys", "Soft, silent, made for restless hands")
        }
    }
    private func row(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Palette.gold).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(KFont.medium(16)).foregroundStyle(Palette.text)
                Text(detail).font(KFont.body(14)).foregroundStyle(Palette.text2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct KitsHome: View {
    @Binding var path: [KitStep]
    var startCheckout: () -> Void
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenTitle(title: "Kits", subtitle: "Things you can hold. Fewer screens, more evening.").padding(.top, 24)
                Button { path.append(.detail) } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        ArtImage(name: "art-kit").frame(height: 150).frame(maxWidth: .infinity).clipped()
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "Kit of the month · \(Date().formatted(.dateTime.month(.wide)))")
                            Text("Quiet hands, slow evening").font(KFont.title(24)).foregroundStyle(Palette.text)
                            Text("\(CheckoutModel.priceCents.dollars) with shipping and tax included. No food or drink.")
                                .font(KFont.body(14)).foregroundStyle(Palette.text2)
                        }
                        .padding(18)
                    }
                    .kCard(radius: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)

                Button("Get this kit") { startCheckout() }.buttonStyle(PrimaryButtonStyle())

                Button { path.append(.orders) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Your orders").font(KFont.heading(20)).foregroundStyle(Palette.text)
                            Text(store.state.orders.isEmpty ? "Nothing ordered yet" : "Track a delivery, skip or cancel")
                                .font(KFont.body(14)).foregroundStyle(Palette.text2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Palette.text2)
                    }
                    .padding(16)
                    .kCard()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .kScreen()
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct KitDetailView: View {
    @Binding var path: [KitStep]
    var startCheckout: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ArtImage(name: "art-kit").frame(height: 170).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                Text("Quiet hands, slow evening").font(KFont.title(28)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
                Text("A box for the evenings you’d rather not look at a screen. Trace the sand tray while a story plays, or read one of the paperbacks in bed.")
                    .font(KFont.body(16)).foregroundStyle(Palette.text2)
                KitContents().padding(16).kCard()
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(CheckoutModel.priceCents.dollars) · shipping and tax included").font(KFont.medium(16)).foregroundStyle(Palette.text)
                    Text("Same price once or monthly. No discounts to chase, no add-ons.").font(KFont.body(14)).foregroundStyle(Palette.text2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .checkoutAction { Button("Get this kit") { startCheckout() }.buttonStyle(PrimaryButtonStyle()) }
        .kScreen()
        .navigationTitle("Kit of the month")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HowOftenView: View {
    @Bindable var model: CheckoutModel
    @Binding var path: [KitStep]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle(title: "How often?", subtitle: "Same price either way. No discounts to chase.")
                option(.once, "Just this once", "One box. Nothing recurring.")
                option(.monthly, "Every month", "A new box each month. We’ll remind you 3 days before it ships. Skip or cancel anytime.")
            }
            .padding(16)
        }
        .checkoutAction { Button("Continue") { path.append(.bag) }.buttonStyle(PrimaryButtonStyle()) }
        .kScreen()
        .navigationTitle("How often")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func option(_ plan: KitPlan, _ title: String, _ detail: String) -> some View {
        let on = model.plan == plan
        return Button { model.plan = plan; Haptics.shared.selection() } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22)).foregroundStyle(on ? Palette.gold : Palette.outlineStrong)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title).font(KFont.heading(20)).foregroundStyle(Palette.text)
                        Spacer()
                        Text(CheckoutModel.priceCents.dollars + (plan == .monthly ? " / month" : "")).font(KFont.medium(16)).foregroundStyle(Palette.text)
                    }
                    Text(detail).font(KFont.body(14)).foregroundStyle(Palette.text2)
                }
            }
            .padding(16)
            .kCard()
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(on ? Palette.gold : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct BagView: View {
    @Bindable var model: CheckoutModel
    @Binding var path: [KitStep]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    ArtImage(name: "art-kit").frame(width: 90, height: 70).clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Quiet hands, slow evening").font(KFont.heading(20)).foregroundStyle(Palette.text)
                        Text(model.plan == .monthly ? "Every month" : "Just this once").font(KFont.body(14)).foregroundStyle(Palette.text2)
                    }
                }
                .padding(14)
                .kCard()
                VStack(spacing: 8) {
                    line("Kit", CheckoutModel.priceCents.dollars)
                    line("Shipping", "Included")
                    line("Tax", "Included")
                    Rectangle().fill(Palette.outline).frame(height: 1)
                    line("Total today", CheckoutModel.priceCents.dollars, bold: true)
                }
                .padding(16)
                .kCard()
            }
            .padding(16)
        }
        .checkoutAction { Button("Continue to shipping") { path.append(.shipping) }.buttonStyle(PrimaryButtonStyle()) }
        .kScreen()
        .navigationTitle("Your bag")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func line(_ a: String, _ b: String, bold: Bool = false) -> some View {
        HStack {
            Text(a).font(bold ? KFont.medium(16) : KFont.body(16)).foregroundStyle(Palette.text)
            Spacer()
            Text(b).font(bold ? KFont.medium(16) : KFont.body(16)).foregroundStyle(Palette.text)
        }
    }
}

/// A labelled text field with an inline error, read out by VoiceOver.
struct CheckoutField: View {
    var label: String
    @Binding var text: String
    var error: String?
    var content: UITextContentType?
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .words

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(KFont.medium(14)).foregroundStyle(Palette.text2)
            TextField("", text: $text)
                .font(KFont.body(16))
                .foregroundStyle(Palette.text)
                .textContentType(content)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.background))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(error == nil ? Palette.outlineStrong : Palette.warm, lineWidth: 1))
                .accessibilityLabel(label)
                .accessibilityHint(error ?? "")
            if let error {
                Label(error, systemImage: "exclamationmark.circle").font(KFont.body(14)).foregroundStyle(Palette.warm)
            }
        }
    }
}

struct ShippingView: View {
    @Bindable var model: CheckoutModel
    @Binding var path: [KitStep]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Step 1 of 3").font(KFont.body(14)).foregroundStyle(Palette.text3)
                Text("Where should it go?").font(KFont.title(24)).foregroundStyle(Palette.text)
                CheckoutField(label: "Full name", text: $model.address.name, error: model.addressErrors["name"], content: .name)
                CheckoutField(label: "Street address", text: $model.address.street, error: model.addressErrors["street"], content: .streetAddressLine1)
                CheckoutField(label: "Apartment, suite (optional)", text: $model.address.apartment, error: nil, content: .streetAddressLine2)
                CheckoutField(label: "City", text: $model.address.city, error: model.addressErrors["city"], content: .addressCity)
                HStack(alignment: .top, spacing: 12) {
                    CheckoutField(label: "State", text: $model.address.state, error: model.addressErrors["state"], content: .addressState, capitalization: .characters)
                        .frame(width: 120)
                    CheckoutField(label: "ZIP code", text: $model.address.zip, error: model.addressErrors["zip"], content: .postalCode, keyboard: .numbersAndPunctuation, capitalization: .never)
                }
                Toggle(isOn: $model.saveAddress) { Text("Remember this address on this phone").font(KFont.body(16)).foregroundStyle(Palette.text) }
                    .tint(Palette.gold)
                Text("Ships within the US. Arrives in 3–7 days.").font(KFont.body(14)).foregroundStyle(Palette.text3)
            }
            .padding(16)
        }
        .checkoutAction {
            Button("Continue to payment") {
                if model.validateAddress() {
                    path.append(.payment)
                } else {
                    Haptics.shared.warning()
                    UIAccessibility.post(notification: .announcement, argument: "Some details need a look. " + model.addressErrors.values.sorted().joined(separator: " "))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .scrollDismissesKeyboard(.interactively)
        .kScreen()
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PaymentView: View {
    @Bindable var model: CheckoutModel
    @Binding var path: [KitStep]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Step 2 of 3").font(KFont.body(14)).foregroundStyle(Palette.text3)
                Text("Payment").font(KFont.title(24)).foregroundStyle(Palette.text)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "testtube.2").foregroundStyle(Palette.gold)
                    Text("Beta test mode: no money is taken. Use 4242 4242 4242 4242 with any future date and any 3 digits.")
                        .font(KFont.body(14)).foregroundStyle(Palette.text)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.gold.opacity(0.12)))
                CheckoutField(label: "Card number", text: $model.cardNumber, error: model.cardErrors["number"], content: .creditCardNumber, keyboard: .numberPad, capitalization: .never)
                    .onChange(of: model.cardNumber) { _, _ in model.formatCardNumber() }
                HStack(alignment: .top, spacing: 12) {
                    CheckoutField(label: "Expiry (MM/YY)", text: $model.expiry, error: model.cardErrors["expiry"], content: nil, keyboard: .numberPad, capitalization: .never)
                        .onChange(of: model.expiry) { _, _ in model.formatExpiry() }
                    CheckoutField(label: "Security code", text: $model.cvc, error: model.cardErrors["cvc"], content: nil, keyboard: .numberPad, capitalization: .never)
                        .onChange(of: model.cvc) { _, value in if value.count > 4 { model.cvc = String(value.prefix(4)) } }
                        .frame(width: 140)
                }
                CheckoutField(label: "Name on card", text: $model.cardName, error: model.cardErrors["cardName"], content: .name)
            }
            .padding(16)
        }
        .checkoutAction {
            Button("Review order") {
                if model.validateCard() {
                    path.append(.review)
                } else {
                    Haptics.shared.warning()
                    UIAccessibility.post(notification: .announcement, argument: "Some card details need a look. " + model.cardErrors.values.sorted().joined(separator: " "))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .scrollDismissesKeyboard(.interactively)
        .kScreen()
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ReviewView: View {
    @Bindable var model: CheckoutModel
    @Binding var path: [KitStep]
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Step 3 of 3").font(KFont.body(14)).foregroundStyle(Palette.text3)
                Text("Review").font(KFont.title(24)).foregroundStyle(Palette.text)
                summaryRow("Kit", model.plan == .monthly ? "Quiet hands, slow evening · every month" : "Quiet hands, slow evening · once", step: .often)
                summaryRow("Ship to", "\(model.address.name), \(model.address.oneLine)", step: .shipping)
                summaryRow("Arrives", "\(Date().addingTimeInterval(3 * 86400).formatted(.dateTime.weekday().month().day())) – \(Date().addingTimeInterval(7 * 86400).formatted(.dateTime.weekday().month().day()))", step: nil)
                summaryRow("Pay with", model.paymentSummary, step: .payment)
                Text(model.plan == .monthly ? "\(CheckoutModel.priceCents.dollars) today, then \(CheckoutModel.priceCents.dollars) each month. Cancel anytime in Profile." : "One-time purchase. Nothing recurring.")
                    .font(KFont.body(14)).foregroundStyle(Palette.text2)
                if let failure = model.paymentFailure {
                    Label(failure, systemImage: "exclamationmark.triangle").font(KFont.body(14)).foregroundStyle(Palette.warm)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.warm.opacity(0.12)))
                }
            }
            .padding(16)
        }
        .checkoutAction {
            Button {
                model.pay { order in
                    guard let order else { Haptics.shared.warning(); return }
                    store.state.orders.insert(order, at: 0)
                    if model.saveAddress { store.state.savedAddress = model.address }
                    PromptScheduler.shared.scheduleKitReminders(for: store.state.orders)
                    Haptics.shared.success()
                    SoundEngine.shared.play(.chime, volume: 0.7)
                    path = [.confirmed(order.id)]
                }
            } label: {
                if model.isPaying {
                    HStack(spacing: 10) { ProgressView().tint(Palette.background); Text("Confirming…") }
                } else {
                    Text("Place order · \(CheckoutModel.priceCents.dollars)")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.isPaying)
            Text("Beta prototype: test mode, no real payment is taken.").font(KFont.body(14)).foregroundStyle(Palette.text3).frame(maxWidth: .infinity)
        }
        .kScreen()
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summaryRow(_ title: String, _ value: String, step: KitStep?) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(KFont.medium(14)).foregroundStyle(Palette.text2)
                Text(value).font(KFont.body(16)).foregroundStyle(Palette.text)
            }
            Spacer()
            if let step {
                Button("Change") {
                    if let i = path.firstIndex(of: step) { path = Array(path.prefix(through: i)) }
                }
                .font(KFont.medium(14))
                .foregroundStyle(Palette.warm)
                .accessibilityLabel("Change \(title.lowercased())")
            }
        }
        .padding(14)
        .kCard(radius: 14)
    }
}

struct ConfirmedView: View {
    var orderID: UUID
    @Binding var path: [KitStep]
    @Environment(AppStore.self) private var store

    var body: some View {
        let order = store.state.orders.first { $0.id == orderID }
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle").font(.system(size: 44)).foregroundStyle(Palette.gold).padding(.top, 30)
                Text("It’s on its way soon.").font(KFont.title(28)).foregroundStyle(Palette.text).multilineTextAlignment(.center)
                if let order {
                    Text(order.plan == .monthly
                         ? "Order \(order.number). \(order.totalCents.dollars) paid today (test mode). We’ll remind you 3 days before the next box."
                         : "Order \(order.number). \(order.totalCents.dollars) paid (test mode). Nothing else will be charged.")
                        .font(KFont.body(16)).foregroundStyle(Palette.text2).multilineTextAlignment(.center)
                    OrderCard(order: order, showActions: false)
                }
                Button("Back to kits") { path = [] }.buttonStyle(PrimaryButtonStyle())
                Button("View orders") { path = [.orders] }.buttonStyle(GhostButtonStyle())
            }
            .padding(16)
        }
        .kScreen()
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Confirmed")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OrderCard: View {
    var order: KitOrder
    var showActions: Bool
    @Environment(AppStore.self) private var store
    @State private var confirmCancel = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Order \(order.number)").font(KFont.medium(16)).foregroundStyle(Palette.text)
                Spacer()
                Text(order.totalCents.dollars).font(KFont.body(16)).foregroundStyle(Palette.text)
            }
            Text("Placed \(order.placedAt.formatted(date: .abbreviated, time: .omitted)) · \(order.paymentSummary)")
                .font(KFont.body(14)).foregroundStyle(Palette.text3)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(KitOrder.Stage.allCases, id: \.rawValue) { stage in
                    let reached = stage.rawValue <= order.stage.rawValue
                    HStack(spacing: 10) {
                        Circle().fill(reached ? Palette.gold : Palette.outline).frame(width: 10, height: 10)
                        Text(stage.label).font(KFont.body(14)).foregroundStyle(reached ? Palette.text : Palette.text3)
                        Spacer()
                        Text(stageDate(stage)).font(KFont.body(14)).foregroundStyle(Palette.text3)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(reached ? "done" : "")
                }
            }
            if order.plan == .monthly {
                Rectangle().fill(Palette.outline).frame(height: 1)
                if order.isActive, let next = order.nextShipDate {
                    Text("Monthly plan · next box ships \(next.formatted(date: .abbreviated, time: .omitted))\(order.skipNextBox ? " (one box skipped)" : "")")
                        .font(KFont.body(14)).foregroundStyle(Palette.text2)
                } else {
                    Text("Monthly plan cancelled. No more charges.").font(KFont.body(14)).foregroundStyle(Palette.text2)
                }
                if showActions {
                    HStack(spacing: 10) {
                        if order.isActive {
                            Button(order.skipNextBox ? "Undo skip" : "Skip next box") { update { $0.skipNextBox.toggle() } }
                                .buttonStyle(SecondaryButtonStyle())
                            Button("Cancel monthly") { confirmCancel = true }
                                .buttonStyle(SecondaryButtonStyle())
                        } else {
                            Button("Restart monthly") { update { $0.isActive = true; $0.skipNextBox = false } }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    .font(KFont.medium(14))
                }
            }
        }
        .padding(16)
        .kCard()
        .confirmationDialog("Cancel your monthly kit?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Cancel monthly plan", role: .destructive) { update { $0.isActive = false } }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("No more boxes and no more charges. The box already on its way still arrives.")
        }
    }

    private func stageDate(_ stage: KitOrder.Stage) -> String {
        let cal = Calendar.current
        switch stage {
        case .ordered: return order.placedAt.formatted(date: .abbreviated, time: .omitted)
        case .packed: return "Within 2 days"
        case .onItsWay: return (cal.date(byAdding: .day, value: 3, to: order.placedAt) ?? order.placedAt).formatted(.dateTime.month().day())
        case .delivered: return "By " + order.arrivesBy.formatted(.dateTime.month().day())
        }
    }

    private func update(_ change: (inout KitOrder) -> Void) {
        guard let i = store.state.orders.firstIndex(where: { $0.id == order.id }) else { return }
        change(&store.state.orders[i])
        PromptScheduler.shared.scheduleKitReminders(for: store.state.orders)
        Haptics.shared.selection()
    }
}

struct OrdersView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if store.state.orders.isEmpty {
                    EmptyState(systemImage: "shippingbox", title: "No orders yet",
                               message: "When you get a kit, you can track it, skip a month or cancel here.")
                } else {
                    ForEach(store.state.orders) { order in OrderCard(order: order, showActions: true) }
                    Text("Beta: orders are saved on this phone. Payments ran in test mode.").font(KFont.body(14)).foregroundStyle(Palette.text3)
                }
            }
            .padding(16)
        }
        .kScreen()
        .navigationTitle("Your orders")
        .navigationBarTitleDisplayMode(.inline)
    }
}
