import SwiftUI

/// Listening, laid out like the Figma prototype: cover, scrubber, controls, "Stop playing" sleep timer,
/// "Still awake? Add time", and Turn screen off. Swipe down anywhere to close.
struct ListenView: View {
    var story: Story
    @Environment(NarrationPlayer.self) private var player
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.komorebiReduceMotion) private var reduce

    @State private var scrubbing = false
    @State private var scrubValue: Double = 0
    @State private var screenOff = false
    @State private var savedBrightness: CGFloat?
    @State private var dragOffset: CGFloat = 0

    private let timerChoices: [NarrationPlayer.SleepTimer] = [.off, .endOfStory, .fifteen, .thirty]

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule().fill(Palette.outlineStrong).frame(width: 40, height: 5).padding(.top, 6).accessibilityHidden(true)
                header
                ScrollView {
                    VStack(spacing: 20) {
                        Image(story.coverImageName)
                            .resizable().scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .accessibilityHidden(true)
                            .padding(.top, 8)
                        VStack(spacing: 6) {
                            Text(story.title).font(KFont.heading(28)).foregroundStyle(Palette.text).multilineTextAlignment(.center)
                            Text("\(story.author) · LibriVox recording").font(KFont.body(14)).foregroundStyle(Palette.text2)
                        }
                        if let problem = player.problem, player.story?.id == story.id {
                            problemCard(problem)
                        } else if !player.isReady {
                            Color.clear.frame(height: 220)
                        } else {
                            scrubber
                            transport
                            sleepTimer
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollBounceBehavior(.basedOnSize)
                VStack(spacing: 8) {
                    Button("Turn screen off") { screenOn(false) }
                        .buttonStyle(SecondaryButtonStyle())
                    Text("Audio keeps playing and fades out gently.").font(KFont.body(14)).foregroundStyle(Palette.text3)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .offset(y: dragOffset)
            .gesture(dismissDrag)

            if !player.isReady && player.problem == nil {
                LoadingView(message: "Getting the narrator ready…", style: .fullScreen, delay: 0.3, slowAfter: 6,
                            slowMessage: "The narration is taking longer than usual to open.",
                            slowActionTitle: "Read the story instead",
                            slowAction: { router.activity = .reader(story.id) })
                    .transition(.opacity)
            }
            if player.askStillAwake { stillAwake.transition(.opacity) }
            if screenOff { screenOffCover.transition(.opacity) }
        }
        .animation(Motion.ease(reduce), value: player.askStillAwake)
        .animation(Motion.ease(reduce), value: screenOff)
        .statusBarHidden(screenOff)
        .onAppear {
            player.load(story)
            if player.problem == nil && !player.isPlaying { player.play() }
        }
        .onDisappear { restoreBrightness() }
    }

    /// Swipe down to close, like a music player.
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { v in
                if v.translation.height > 0 && abs(v.translation.height) > abs(v.translation.width) {
                    dragOffset = reduce ? 0 : v.translation.height * 0.6
                }
            }
            .onEnded { v in
                if v.translation.height > 120 || v.predictedEndTranslation.height > 260 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { dragOffset = 0 }
                }
            }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CircleIconButton(systemImage: "xmark", label: "Close player") { dismiss() }
            Text("Listening").font(KFont.heading(20)).foregroundStyle(Palette.text)
            Spacer()
            CircleIconButton(systemImage: "book", label: "Read along") {
                // Keep playing and follow the words in the reader.
                router.activity = .reader(story.id)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var scrubber: some View {
        VStack(spacing: 6) {
            Slider(value: Binding(get: { scrubbing ? scrubValue : player.elapsed },
                                  set: { scrubValue = $0 }),
                   in: 0...max(1, player.duration)) { editing in
                scrubbing = editing
                if !editing { player.seek(to: scrubValue) } else { scrubValue = player.elapsed }
            }
            .tint(Palette.gold)
            .accessibilityLabel("Position")
            .accessibilityValue("\(player.elapsed.playbackTime) of \(player.duration.playbackTime)")
            HStack {
                Text((scrubbing ? scrubValue : player.elapsed).playbackTime)
                Spacer()
                Text("-" + max(0, player.duration - (scrubbing ? scrubValue : player.elapsed)).playbackTime)
            }
            .font(KFont.body(14, relativeTo: .caption))
            .foregroundStyle(Palette.text2)
            .monospacedDigit()
        }
    }

    private var transport: some View {
        HStack(spacing: 26) {
            Spacer(minLength: 0)
            Button { player.skip(by: -15) } label: { roundIcon("gobackward.15") }
                .accessibilityLabel("Back 15 seconds")
            Button { player.toggle(); Haptics.shared.tap() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Palette.background)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(Palette.gold))
            }
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            Button { player.skip(by: 15) } label: { roundIcon("goforward.15") }
                .accessibilityLabel("Forward 15 seconds")
            Button {
                let next: Float = player.rate >= 1 ? 0.9 : (player.rate >= 0.89 ? 0.8 : 1.0)
                player.setRate(next)
                Haptics.shared.selection()
            } label: {
                Text(player.rate == 1 ? "1×" : String(format: "%.1f×", player.rate))
                    .font(KFont.medium(14)).foregroundStyle(Palette.text)
                    .frame(width: 48, height: 32)
                    .overlay(Capsule().strokeBorder(Palette.text.opacity(0.8)))
                    .frame(height: 44)
            }
            .accessibilityLabel("Speed \(player.rate == 1 ? "normal" : String(format: "%.1f", player.rate))")
            Spacer(minLength: 0)
        }
        .buttonStyle(.plain)
    }

    private func roundIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 18))
            .foregroundStyle(Palette.text)
            .frame(width: 44, height: 44)
            .overlay(Circle().strokeBorder(Palette.text.opacity(0.8)))
    }

    private var sleepTimer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Stop playing").font(KFont.medium(16)).foregroundStyle(Palette.text)
                Spacer()
                if let end = player.sleepEndsAt, player.isPlaying {
                    HStack(spacing: 4) {
                        Text("Fades out in")
                        Text(timerInterval: Date()...max(Date(), end), countsDown: true).monospacedDigit()
                    }
                    .font(KFont.body(14)).foregroundStyle(Palette.gold)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(timerChoices) { option in
                        let on = player.sleepTimer == option
                        Button {
                            player.setSleepTimer(option)
                            Haptics.shared.selection()
                        } label: {
                            Text(option.label)
                                .font(on ? KFont.medium(14) : KFont.body(14))
                                .foregroundStyle(on ? Palette.background : Palette.text)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 36)
                                .background(Capsule().fill(on ? Palette.surface : .clear))
                                .overlay(Capsule().strokeBorder(on ? .clear : Palette.text.opacity(0.7)))
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            if player.sleepEndsAt != nil {
                HStack {
                    Text("Still awake? Add time").font(KFont.body(14)).foregroundStyle(Palette.text2)
                    Spacer()
                    ForEach([5.0, 15.0], id: \.self) { m in
                        Button { player.addTime(minutes: m) } label: {
                            Text("+ \(Int(m)) min").font(KFont.medium(14)).foregroundStyle(Palette.gold)
                                .padding(.horizontal, 14).frame(minHeight: 36)
                                .overlay(Capsule().strokeBorder(Palette.gold))
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add \(Int(m)) minutes")
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(Motion.ease(reduce), value: player.sleepEndsAt != nil)
    }

    private func problemCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "speaker.slash").font(.system(size: 26)).foregroundStyle(Palette.gold)
            Text(message).font(KFont.body(16)).foregroundStyle(Palette.text).multilineTextAlignment(.center)
            Button("Read the story") { router.activity = .reader(story.id) }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .kCard()
    }

    private var stillAwake: some View {
        VStack(spacing: 14) {
            Text("Still awake?").font(KFont.heading(24)).foregroundStyle(Palette.text)
            Text("The story paused where you left off. You’ll find it on Tonight.").font(KFont.body(16)).foregroundStyle(Palette.text2).multilineTextAlignment(.center)
            Button("15 more minutes") { player.addFifteenMinutes() }.buttonStyle(PrimaryButtonStyle())
            Button("Goodnight") {
                player.askStillAwake = false
                player.pause()
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(24)
        .kCard(radius: 24)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.55).ignoresSafeArea())
    }

    private var screenOffCover: some View {
        Color.black
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                Text("Tap anywhere to wake").font(KFont.body(14)).foregroundStyle(Color.white.opacity(0.18)).padding(.bottom, 40)
            }
            .onTapGesture { screenOn(true) }
            .accessibilityElement()
            .accessibilityLabel("Screen off. Story still playing.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { screenOn(true) }
    }

    private func screenOn(_ on: Bool) {
        let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen
        if on {
            restoreBrightness()
            screenOff = false
        } else {
            savedBrightness = screen?.brightness
            screen?.brightness = 0.01
            screenOff = true
        }
    }

    private func restoreBrightness() {
        if let saved = savedBrightness {
            (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.brightness = saved
            savedBrightness = nil
        }
    }
}
