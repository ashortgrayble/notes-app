import SwiftUI
import UIKit

enum Theme {
    static let paper = Color(red: 0.965, green: 0.949, blue: 0.918)
    static let stripPaper = Color(red: 0.992, green: 0.984, blue: 0.965)
    static let ink = Color(red: 0.11, green: 0.10, blue: 0.09)
    static let faint = Color(red: 0.11, green: 0.10, blue: 0.09).opacity(0.35)

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
