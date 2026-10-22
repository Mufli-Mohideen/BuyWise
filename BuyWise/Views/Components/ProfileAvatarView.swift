import SwiftUI

/// The user's profile photo, falling back to the bundled default avatar.
struct ProfileAvatarView: View {
    @EnvironmentObject private var appState: AppState
    var size: CGFloat = 44
    var ringColor: Color = .white

    var body: some View {
        avatarImage
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(ringColor, lineWidth: size > 60 ? 3 : 2))
            .accessibilityLabel("Profile photo")
    }

    private var avatarImage: Image {
        if let data = appState.profileImageData, let image = UIImage(data: data) {
            return Image(uiImage: image)
        }
        return Image("ProfileAvatar")
    }
}

struct NotificationBellButton: View {
    @EnvironmentObject private var appState: AppState
    var style: Style = .onBrand
    let action: () -> Void

    enum Style { case onBrand, onSurface }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(style == .onBrand ? Color.white.opacity(0.18) : BuyWiseColors.surface)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "bell.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(style == .onBrand ? .white : BuyWiseColors.textPrimary)
                    )
                if appState.unreadCount > 0 {
                    Text("\(appState.unreadCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, 3)
                        .background(Capsule().fill(Color(hex: "E11D48")))
                        .overlay(Capsule().strokeBorder(style == .onBrand ? BuyWiseColors.brand : BuyWiseColors.surface, lineWidth: 2))
                        .offset(x: 4, y: -2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: appState.unreadCount)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(appState.unreadCount > 0 ? "Alerts, \(appState.unreadCount) unread" : "Alerts")
    }
}

extension UIImage {
    /// Shrinks a picked photo so its longest side is at most `maxDimension` before saving.
    func resizedForAvatar(maxDimension: CGFloat = 600) -> UIImage {
        let scale = min(1, maxDimension / max(size.width, size.height))
        guard scale < 1 else { return self }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: target).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
