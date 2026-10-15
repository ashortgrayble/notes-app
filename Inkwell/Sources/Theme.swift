import SwiftUI
import UIKit

enum Theme {
    // A cool, inky palette: pale verdigris paper, deep indigo ink, one persimmon accent.
    static let paper = Color(red: 0.886, green: 0.918, blue: 0.902)       // #E2EAE6 note background
    static let card = Color(red: 0.969, green: 0.973, blue: 0.965)        // #F7F8F6 note cards, a softer off-white
    static let stripPaper = Color(red: 0.949, green: 0.965, blue: 0.953)  // #F2F6F3 writing surface
    static let ink = Color(red: 0.106, green: 0.137, blue: 0.251)         // #1B2340 indigo-black
    static let accent = Color(red: 0.678, green: 0.255, blue: 0.161)      // #AD4129 persimmon (4.8:1+ on every surface)
    /// Secondary text and icons: #4B5468, at least 6:1 on the page, cards and writing surface.
    static let faint = Color(red: 0.294, green: 0.329, blue: 0.408)

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
