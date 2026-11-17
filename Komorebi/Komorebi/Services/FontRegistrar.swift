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

/// Komorebi type: Urbanist for titles, Prompt for everything else, Literata for the serif reading option.
/// Every style scales with Dynamic Type and with Komorebi's own Text size setting.
/// If a font file isn't bundled, SwiftUI falls back to the system font at the same size and weight.
enum KFont {
    static func title(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("Urbanist-Bold", size: size, relativeTo: style).weight(.bold)
    }

    static func heading(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        .custom("Urbanist-Bold", size: size, relativeTo: style).weight(.semibold)
    }

    static func body(_ size: CGFloat = 16, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Prompt-Regular", size: size, relativeTo: style)
    }

    static func medium(_ size: CGFloat = 16, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Prompt-Medium", size: size, relativeTo: style).weight(.medium)
    }

    static func light(_ size: CGFloat = 16, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Prompt-Light", size: size, relativeTo: style).weight(.light)
    }

    /// Reading text in the person's chosen size.
    static func reading(_ size: CGFloat, serif: Bool) -> Font {
        if serif {
            if FontRegistrar.has("Literata-Regular") { return .custom("Literata-Regular", size: size, relativeTo: .body) }
            return .system(size: UIFontMetrics.default.scaledValue(for: size), design: .serif)
        }
        return .custom("Prompt-Regular", size: size, relativeTo: .body)
    }
}
