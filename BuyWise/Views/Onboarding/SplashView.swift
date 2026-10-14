import SwiftUI

struct SplashView: View {
    var onFinished: () -> Void

    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var taglineOpacity: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                Image("BuyWiseLogoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)

            VStack(spacing: 6) {
                Text("BuyWise")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(BuyWiseColors.textPrimary)
                Text("Buy smarter. Spend better.")
                    .font(BuyWiseTypography.subheadline)
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }
            .opacity(taglineOpacity)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .bwScreenBackground()
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                logoScale = 1
                logoOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
                taglineOpacity = 1
            }
            Task {
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                onFinished()
            }
        }
    }
}
