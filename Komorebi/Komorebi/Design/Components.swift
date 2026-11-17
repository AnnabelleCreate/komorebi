import SwiftUI

// MARK: - Motion

private struct ReduceMotionKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// Komorebi's Reduce Motion: the iPhone setting unless changed in Settings.
    var komorebiReduceMotion: Bool {
        get { self[ReduceMotionKey.self] }
        set { self[ReduceMotionKey.self] = newValue }
    }
}

enum Motion {
    /// Soft fades are kept with Reduce Motion; only movement is removed.
    static func ease(_ reduce: Bool, duration: Double = 0.45) -> Animation {
        reduce ? .easeInOut(duration: 0.3) : .timingCurve(0.22, 0.8, 0.24, 1, duration: duration)
    }

    static func screen(_ reduce: Bool) -> AnyTransition {
        reduce ? .opacity : .opacity.combined(with: .offset(y: 10))
    }
}

// MARK: - Text size

struct AppTextSize: ViewModifier {
    var choice: TextSizeChoice
    func body(content: Content) -> some View {
        switch choice {
        case .standard: content
        case .large: content.dynamicTypeSize(.xLarge ... .accessibility3)
        case .larger: content.dynamicTypeSize(.xxxLarge ... .accessibility5)
        }
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth = true
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KFont.medium(16))
            .foregroundStyle(Palette.background)
            .padding(.horizontal, 24)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 52)
            .background(Capsule().fill(Palette.gold))
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var fullWidth = true
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KFont.medium(16))
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 22)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 52)
            .background(Capsule().strokeBorder(Palette.text.opacity(0.9), lineWidth: 1.5))
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .contentShape(Capsule())
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KFont.medium(15))
            .foregroundStyle(Palette.gold)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

/// A round 44 pt icon button.
struct CircleIconButton: View {
    var systemImage: String
    var label: String
    var filled = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(filled ? Palette.background : Palette.text)
                .frame(width: 44, height: 44)
                .background(Circle().fill(filled ? Palette.gold : Palette.cardRaised))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Surfaces

struct CardBackground: ViewModifier {
    var radius: CGFloat = 18
    var raised = true
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(raised ? Palette.cardRaised : Palette.card))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Palette.outline.opacity(0.9), lineWidth: 1))
    }
}

extension View {
    func kCard(radius: CGFloat = 18, raised: Bool = true) -> some View { modifier(CardBackground(radius: radius, raised: raised)) }

    /// Standard screen background.
    func kScreen() -> some View {
        self.background(Palette.background.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .toolbarBackground(Palette.background, for: .navigationBar)
    }
}

// MARK: - Chips, headers

struct ActivityTag: View {
    var text: String
    var systemImage: String?
    var filled = false
    var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 12, weight: .medium)) }
            Text(text).font(KFont.body(13, relativeTo: .caption))
        }
        .padding(.horizontal, 9)
        .frame(minHeight: 28)
        .foregroundStyle(filled ? Palette.background : Palette.text2)
        .background(RoundedRectangle(cornerRadius: 7).fill(filled ? Color(hex: 0xC4AD7B) : .clear))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(filled ? .clear : Palette.outlineStrong, lineWidth: 1))
    }
}

struct FilterChip: View {
    var title: String
    var selected: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(selected ? KFont.medium(14) : KFont.body(14))
                .padding(.horizontal, 15)
                .frame(minHeight: 44)
                .foregroundStyle(selected ? Palette.background : Palette.text2)
                .background(Capsule().fill(selected ? Palette.text : .clear))
                .overlay(Capsule().strokeBorder(selected ? .clear : Palette.outlineStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ScreenTitle: View {
    var title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(KFont.title(32, relativeTo: .largeTitle))
                .foregroundStyle(Palette.text)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).font(KFont.body(15)).foregroundStyle(Palette.text2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(KFont.medium(12, relativeTo: .caption))
            .tracking(1.6)
            .foregroundStyle(Palette.gold)
            .accessibilityAddTraits(.isHeader)
    }
}

struct Eyebrow: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(KFont.medium(12, relativeTo: .caption))
            .tracking(1.6)
            .foregroundStyle(Palette.gold)
    }
}

/// Pill segmented control used across Settings and Profile.
struct PillPicker<Value: Hashable>: View {
    var options: [(Value, String)]
    @Binding var selection: Value
    var label: String
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let on = option.0 == selection
                Button {
                    selection = option.0
                    Haptics.shared.selection()
                    SoundEngine.shared.play(.tap, volume: 0.6)
                } label: {
                    Text(option.1)
                        .font(on ? KFont.medium(14) : KFont.body(14))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(on ? Palette.background : Palette.text2)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(on ? Palette.text : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(Palette.background))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// A row in a settings list.
struct SettingRow<Trailing: View>: View {
    var title: String
    var detail: String?
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(KFont.body(16)).foregroundStyle(Palette.text)
                if let detail { Text(detail).font(KFont.body(13, relativeTo: .footnote)).foregroundStyle(Palette.text2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
    }
}

/// Grouped settings card with hairline dividers between rows.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .kCard(radius: 14)
    }
}

struct RowDivider: View {
    var body: some View { Rectangle().fill(Palette.outline).frame(height: 1).padding(.leading, 16) }
}

/// Image for an activity or story, used in cards and lists.
struct ArtImage: View {
    var name: String
    var body: some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .accessibilityHidden(true)
    }
}

struct EmptyState: View {
    var systemImage: String
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage).font(.system(size: 30)).foregroundStyle(Palette.gold)
            Text(title).font(KFont.heading(18)).foregroundStyle(Palette.text)
            Text(message).font(KFont.body(14)).foregroundStyle(Palette.text2).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(SecondaryButtonStyle(fullWidth: false)).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
    }
}

extension Int {
    /// "8:00 PM" for minutes after midnight.
    var clockString: String {
        var parts = DateComponents()
        parts.hour = self / 60
        parts.minute = self % 60
        let date = Calendar.current.date(from: parts) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

extension Double {
    /// "12:04" style time.
    var playbackTime: String {
        let s = Swift.max(0, Int(self.isFinite ? self : 0))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
