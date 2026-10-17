import SwiftUI

private struct OnboardingPage: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
}

private let onboardingPages: [OnboardingPage] = [
    OnboardingPage(id: 0, title: "Compare before you buy", subtitle: "See prices from Celltronics and Abans in one place."),
    OnboardingPage(id: 1, title: "Know the real value", subtitle: "Go beyond price with specifications, price history and BuyWise value scores."),
    OnboardingPage(id: 2, title: "Track better prices", subtitle: "Keep an eye on products and discover when prices drop.")
]

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < onboardingPages.count - 1 {
                    Button("Skip") { onComplete() }
                        .font(BuyWiseTypography.subheadline)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .frame(height: 32)

            TabView(selection: $page) {
                ForEach(onboardingPages) { item in
                    onboardingPageContent(item)
                        .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            HStack(spacing: 8) {
                ForEach(onboardingPages) { item in
                    Capsule()
                        .fill(item.id == page ? BuyWiseColors.brand : BuyWiseColors.border)
                        .frame(width: item.id == page ? 20 : 7, height: 7)
                        .animation(.easeInOut(duration: 0.2), value: page)
                }
            }
            .padding(.bottom, 24)

            PrimaryButton(title: page == onboardingPages.count - 1 ? "Get Started" : "Continue") {
                if page == onboardingPages.count - 1 {
                    onComplete()
                } else {
                    withAnimation { page += 1 }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .bwScreenBackground()
    }

    @ViewBuilder
    private func onboardingPageContent(_ item: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()

            illustration(for: item.id)
                .frame(height: 220)

            VStack(spacing: 10) {
                Text(item.title)
                    .font(BuyWiseTypography.titleXL)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text(item.subtitle)
                    .font(BuyWiseTypography.body)
                    .foregroundStyle(BuyWiseColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer()
            Spacer()
        }
    }

    @ViewBuilder
    private func illustration(for pageIndex: Int) -> some View {
        switch pageIndex {
        case 0:
            HStack(spacing: 14) {
                RetailerPriceCard(listing: RetailerListing(retailer: .celltronics, price: 94_990), isLowest: false)
                RetailerPriceCard(listing: RetailerListing(retailer: .abans, price: 89_990), isLowest: true)
            }
            .padding(.horizontal, 28)
        case 1:
            VStack(spacing: 16) {
                ValueScoreGauge(score: 8.7, size: 130)
                Text("Strong Value")
                    .font(BuyWiseTypography.headline)
                    .foregroundStyle(BuyWiseTheme.valueScoreColor(8.7))
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ProductImageView(category: .headphones, cornerRadius: BuyWiseTheme.smallRadius, emphasized: true)
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WH-1000XM5")
                            .font(BuyWiseTypography.subheadline)
                            .foregroundStyle(BuyWiseColors.textPrimary)
                        Text("LKR 89,990")
                            .font(BuyWiseTypography.priceMedium)
                            .foregroundStyle(BuyWiseColors.textPrimary)
                    }
                    Spacer()
                    PriceDropBadge(percent: 5.3)
                }
            }
            .padding(16)
            .bwCard()
            .padding(.horizontal, 36)
        }
    }
}
