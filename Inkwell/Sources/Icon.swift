import SwiftUI

/// The app's icons, from Iconoir (https://iconoir.com, MIT; see ICONOIR-LICENSE.txt).
/// They're template images, so they take the surrounding foreground color.
enum IconName: String {
    case erase
    case trash
    case editPencil = "edit-pencil"
    case designPencil = "design-pencil"
    case back = "nav-arrow-left"
    case forward = "nav-arrow-right"
}

struct Icon: View {
    let name: IconName
    var size: CGFloat = 22

    init(_ name: IconName, size: CGFloat = 22) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image("icon-\(name.rawValue)")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

/// An icon on a squared card, matching the note cards. At least 44×44 to tap.
struct CardIconLabel: View {
    let name: IconName

    init(_ name: IconName) { self.name = name }

    var body: some View {
        Icon(name, size: 22)
            .foregroundStyle(Theme.ink)
            .frame(width: 44, height: 44)
            .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(Theme.card))
            .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

// Hiding the system back button also disables swipe-to-go-back; this restores it.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
