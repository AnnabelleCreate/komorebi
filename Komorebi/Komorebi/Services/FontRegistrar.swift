import CoreText
import SwiftUI
import UIKit

/// Registers any Urbanist, Prompt or Literata font files bundled in the app.
/// If a font file is missing, Komorebi falls back to the closest system font.
enum FontRegistrar {
    static func registerBundledFonts() {
        for ext in ["ttf", "otf"] {
            let urls = (Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [])
                + (Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: "Fonts") ?? [])
            for url in urls {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    private static var cache: [String: Bool] = [:]

    static func has(_ name: String) -> Bool {
        if let known = cache[name] { return known }
        let found = UIFont(name: name, size: 12) != nil
        cache[name] = found
        return found
    }
}

/// Komorebi type, from the Figma design system:
/// display 32 Urbanist ExtraBold · heading-lg 28 / heading-md 24 / heading-sm 20 Urbanist Bold ·
/// body-lg 18 and body-sm 16 Prompt Regular (Medium for bold) · caption 14 Prompt Regular.
/// The fonts are bundled (Resources/Fonts) and listed in Info.plist; every style scales with Dynamic Type.
enum KFont {
    static func title(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(size >= 30 ? "Urbanist-ExtraBold" : "Urbanist-Bold", size: size, relativeTo: style)
    }

    static func heading(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        .custom("Urbanist-Bold", size: size, relativeTo: style)
    }

    static func body(_ size: CGFloat = 16, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Prompt-Regular", size: size, relativeTo: style)
    }

    static func medium(_ size: CGFloat = 16, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Prompt-Medium", size: size, relativeTo: style)
    }

    static func light(_ size: CGFloat = 16, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Prompt-Light", size: size, relativeTo: style)
    }

    /// Reading text in the person's chosen size: Literata for serif, Prompt for sans.
    static func reading(_ size: CGFloat, serif: Bool) -> Font {
        .custom(serif ? "Literata-Regular" : "Prompt-Regular", size: size, relativeTo: .body)
    }

    /// The same reading font as a UIFont, used to lay out book pages.
    static func readingUIFont(_ size: CGFloat, serif: Bool) -> UIFont {
        let scaled = UIFontMetrics(forTextStyle: .body).scaledValue(for: size)
        return UIFont(name: serif ? "Literata-Regular" : "Prompt-Regular", size: scaled)
            ?? (serif ? UIFont(descriptor: UIFont.systemFont(ofSize: scaled).fontDescriptor.withDesign(.serif) ?? UIFont.systemFont(ofSize: scaled).fontDescriptor, size: scaled)
                      : UIFont.systemFont(ofSize: scaled))
    }
}
