import SwiftUI

/// First-time setup: three short questions, all skippable.
struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(PromptScheduler.self) private var prompts
    @Environment(\.komorebiReduceMotion) private var reduce

    @State private var step = 0
    @State private var name = ""
    @State private var textSize: TextSizeChoice = .standard
    @State private var wantsPrompt = true
    @State private var eveningTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if step > 0 {
                    Button { withAnimation(Motion.ease(reduce)) { step -= 1 } } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }
                    .foregroundStyle(Palette.text)
                    .accessibilityLabel("Back")
                }
                Spacer()
                if step > 0 && step < 4 {
                    Text("\(step) of 3").font(KFont.body(14)).foregroundStyle(Palette.text3)
                    Spacer()
                }
                Button("Skip for now") { finish(skipped: true) }
                    .buttonStyle(GhostButtonStyle())
            }
            .padding(.horizontal, 16)
            .frame(height: 52)

            ZStack {
                switch step {
                case 0: welcome.transition(Motion.screen(reduce))
                case 1: nameStep.transition(Motion.screen(reduce))
                case 2: sizeStep.transition(Motion.screen(reduce))
                default: eveningStep.transition(Motion.screen(reduce))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)

            Button(step == 0 ? "Begin" : (step == 3 ? "Start my evenings" : "Continue")) { advance() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .background(Palette.background.ignoresSafeArea())
        .dynamicTypeSize(textSize == .standard ? .large ... .accessibility5 : (textSize == .large ? .xLarge ... .accessibility5 : .xxxLarge ... .accessibility5))
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            Spacer()
            Image("art-garden-tall")
                .resizable().scaledToFill()
                .frame(width: 200, height: 270)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .accessibilityHidden(true)
            VStack(spacing: 10) {
                Text("komorebi").font(KFont.title(40, relativeTo: .largeTitle)).foregroundStyle(Palette.text)
                Text("Sunlight through leaves, at the end of the day. A few slow things to do before bed — and nothing to keep score of.")
                    .font(KFont.body(16)).foregroundStyle(Palette.text2).multilineTextAlignment(.center)
            }
            Spacer()
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("What should we call you?").font(KFont.title(28)).foregroundStyle(Palette.text)
            Text("Only used to greet you. It stays on this phone.").font(KFont.body(16)).foregroundStyle(Palette.text2)
            TextField("", text: $name, prompt: Text("Your first name").foregroundStyle(Palette.text3))
                .font(KFont.body(18))
                .foregroundStyle(Palette.text)
                .textContentType(.givenName)
                .submitLabel(.continue)
                .focused($nameFocused)
                .onSubmit { advance() }
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
                .kCard(radius: 14)
                .onChange(of: name) { _, value in if value.count > 30 { name = String(value.prefix(30)) } }
            Spacer(); Spacer()
        }
        .onAppear { nameFocused = true }
    }

    private var sizeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("How big should text be?").font(KFont.title(28)).foregroundStyle(Palette.text)
            Text("You can change this anytime in Settings.").font(KFont.body(16)).foregroundStyle(Palette.text2)
            VStack(spacing: 10) {
                ForEach(TextSizeChoice.allCases) { choice in
                    Button {
                        textSize = choice
                        Haptics.shared.selection()
                    } label: {
                        HStack {
                            Text(choice.label).font(KFont.medium(16))
                            Spacer()
                            Image(systemName: textSize == choice ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(textSize == choice ? Palette.gold : Palette.outlineStrong)
                        }
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        .kCard(radius: 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(textSize == choice ? .isSelected : [])
                }
            }
            Text("“Only let me make my life simple and straight, like a flute of reed.”")
                .font(KFont.reading(18, serif: true)).foregroundStyle(Palette.text2)
                .padding(.top, 6)
            Spacer(); Spacer()
        }
    }

    private var eveningStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("When do your evenings wind down?").font(KFont.title(28)).foregroundStyle(Palette.text)
            Text("Komorebi can send one quiet suggestion around then. Never streaks, never reminders to come back.")
                .font(KFont.body(16)).foregroundStyle(Palette.text2)
            VStack(spacing: 0) {
                Toggle(isOn: $wantsPrompt) {
                    Text("Send me a gentle evening prompt").font(KFont.body(16)).foregroundStyle(Palette.text)
                }
                .tint(Palette.gold)
                .padding(.horizontal, 16).frame(minHeight: 56)
                RowDivider()
                DatePicker(selection: $eveningTime, displayedComponents: .hourAndMinute) {
                    Text("Around").font(KFont.body(16)).foregroundStyle(Palette.text)
                }
                .disabled(!wantsPrompt)
                .opacity(wantsPrompt ? 1 : 0.4)
                .padding(.horizontal, 16).frame(minHeight: 56)
            }
            .kCard(radius: 14)
            if prompts.permission == .denied && wantsPrompt {
                Text("Notifications are off for Komorebi in iPhone Settings. You can turn them on later, or use the Lock Screen widget instead.")
                    .font(KFont.body(14)).foregroundStyle(Palette.warm)
            }
            Spacer(); Spacer()
        }
    }

    private func advance() {
        Haptics.shared.tap()
        if step < 3 {
            withAnimation(Motion.ease(reduce)) { step += 1 }
        } else {
            finish(skipped: false)
        }
    }

    private func finish(skipped: Bool) {
        var state = store.state
        state.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        state.textSize = textSize
        if !skipped {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: eveningTime)
            state.evening.startMinutes = (parts.hour ?? 20) * 60 + (parts.minute ?? 0)
            state.evening.endMinutes = (state.evening.startMinutes + 120) % (24 * 60)
            state.evening.isOn = wantsPrompt
            state.evening.style = .notification
        }
        state.onboarded = true
        store.state = state
        SoundEngine.shared.play(.bell, volume: 0.6)
        if !skipped && wantsPrompt && prompts.permission != .allowed {
            prompts.requestPermission()
        }
    }
}
