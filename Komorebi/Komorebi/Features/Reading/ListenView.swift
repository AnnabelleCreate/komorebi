import SwiftUI

/// Listening: LibriVox narration with a sleep timer, Lock Screen controls and a screen-off mode.
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

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hexString: story.palette.last ?? "#1C2139").opacity(0.55), Palette.background],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            Palette.background.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    CircleIconButton(systemImage: "chevron.down", label: "Close player") { dismiss() }
                    Spacer()
                    Text("Listening").font(KFont.heading(17)).foregroundStyle(Palette.text)
                    Spacer()
                    CircleIconButton(systemImage: "book", label: "Read along instead") {
                        player.pause()
                        router.activity = .reader(story.id)
                    }
                }
                .padding(.top, 8)

                StoryCover(story: story).frame(maxWidth: 210).padding(.top, 6)

                VStack(spacing: 4) {
                    Text(story.title).font(KFont.title(24)).foregroundStyle(Palette.text).multilineTextAlignment(.center)
                    Text("\(story.author) · read by a LibriVox volunteer").font(KFont.body(14)).foregroundStyle(Palette.text2)
                }

                if let problem = player.problem, player.story?.id == story.id {
                    problemCard(problem)
                } else {
                    scrubber
                    transport
                    sleepTimer
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)

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
            .font(KFont.body(12, relativeTo: .caption))
            .foregroundStyle(Palette.text3)
            .monospacedDigit()
        }
    }

    private var transport: some View {
        HStack(spacing: 28) {
            Button {
                let next: Float = player.rate >= 1 ? 0.8 : (player.rate < 0.85 ? 0.9 : 1.0)
                player.setRate(next)
                Haptics.shared.selection()
            } label: {
                Text(player.rate == 1 ? "1×" : String(format: "%.1f×", player.rate))
                    .font(KFont.medium(15)).foregroundStyle(Palette.text)
                    .frame(width: 48, height: 44)
            }
            .accessibilityLabel("Speed \(player.rate == 1 ? "normal" : String(format: "%.1f", player.rate))")

            Button { player.skip(by: -15) } label: { Image(systemName: "gobackward.15").font(.system(size: 26)) }
                .accessibilityLabel("Back 15 seconds")
            Button { player.toggle(); Haptics.shared.tap() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Palette.background)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(Palette.gold))
            }
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            Button { player.skip(by: 15) } label: { Image(systemName: "goforward.15").font(.system(size: 26)) }
                .accessibilityLabel("Forward 15 seconds")
            Button { screenOn(false) } label: { Image(systemName: "moon.zzz").font(.system(size: 22)).frame(width: 48, height: 44) }
                .accessibilityLabel("Screen off")
        }
        .foregroundStyle(Palette.text)
        .buttonStyle(.plain)
    }

    private var sleepTimer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sleep timer").font(KFont.medium(14)).foregroundStyle(Palette.text2)
                Spacer()
                if let end = player.sleepEndsAt, player.isPlaying {
                    Text(timerInterval: Date()...max(Date(), end), countsDown: true)
                        .font(KFont.body(13)).foregroundStyle(Palette.gold).monospacedDigit()
                        .frame(maxWidth: 80, alignment: .trailing)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(NarrationPlayer.SleepTimer.allCases) { option in
                        FilterChip(title: option.label, selected: player.sleepTimer == option) {
                            player.setSleepTimer(option)
                            Haptics.shared.selection()
                        }
                    }
                }
            }
            Text("The voice fades out gently when the timer ends.").font(KFont.body(12, relativeTo: .caption)).foregroundStyle(Palette.text3)
        }
        .padding(16)
        .kCard(radius: 16, raised: false)
    }

    private func problemCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "speaker.slash").font(.system(size: 26)).foregroundStyle(Palette.gold)
            Text(message).font(KFont.body(15)).foregroundStyle(Palette.text).multilineTextAlignment(.center)
            Button("Read the story") { router.activity = .reader(story.id) }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .kCard()
    }

    private var stillAwake: some View {
        VStack(spacing: 14) {
            Text("Still awake?").font(KFont.title(26)).foregroundStyle(Palette.text)
            Text("The story paused where you left off.").font(KFont.body(15)).foregroundStyle(Palette.text2)
            Button("15 more minutes") { player.addFifteenMinutes() }.buttonStyle(PrimaryButtonStyle())
            Button("Goodnight") {
                player.askStillAwake = false
                player.stop()
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
                Text("Tap anywhere to wake").font(KFont.body(13)).foregroundStyle(Color.white.opacity(0.18)).padding(.bottom, 40)
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
