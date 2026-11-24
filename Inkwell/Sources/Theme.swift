import SwiftUI
import UIKit

enum Theme {
    // Whites, grays and black. Nothing else.
    static let paper = Color(white: 0.922)        // #EBEBEB note background
    static let card = Color(white: 0.969)         // #F7F7F7 note cards, a softer off-white
    static let stripPaper = Color.white           // #FFFFFF writing surface
    static let ink = Color.black                  // text, icons and ink
    static let accent = Color.black               // emphasis (highlights, strike-through, clear)
    /// Secondary text and icons: #555555, at least 6:1 on the page, cards and writing surface.
    static let faint = Color(white: 0.333)

    /// Corner radius shared by note cards and card-style buttons.
    static let cardRadius: CGFloat = 18

    /// Newsreader ships as a variable font (wght + opsz axes), so we pin the
    /// axes ourselves. Falls back to the system serif if the font fails to load.
    static func serif(size: CGFloat, weight: CGFloat = 400, italic: Bool = false) -> Font {
        let name = italic ? "Newsreader16pt-Italic" : "Newsreader16pt-Regular"
        guard UIFont(name: name, size: size) != nil else {
            return .system(size: size, design: .serif)
        }
        let wghtTag = 0x77676874 // 'wght'
        let opszTag = 0x6F70737A // 'opsz'
        let variation: [Int: CGFloat] = [
            wghtTag: weight,
            opszTag: min(max(size, 6), 72),
        ]
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: name,
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: variation,
        ])
        return Font(UIFont(descriptor: descriptor, size: size))
    }

    static let body = serif(size: 26)
}
