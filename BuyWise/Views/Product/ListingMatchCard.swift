import SwiftUI

struct ListingMatchCard: View {
    let category: ProductCategory
    let match: ListingMatch

    @State private var showRejected = false

    private var checklistItems: [(label: String, isTrue: Bool)] {
        var items: [(String, Bool)] = [("Same model", match.modelMatched)]
        if category == .smartphones || category == .laptops {
            items.append(("Same storage", match.storageMatched))
        }
        items.append(("Same variant", match.variantMatched))
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "Product match")
                Text("\(match.confidencePercent)% match")
                    .font(BuyWiseTypography.captionBold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(BuyWiseColors.success.opacity(0.14)))
                    .foregroundStyle(BuyWiseColors.success)
                    .fixedSize()
            }

            VStack(spacing: 0) {
                ForEach(Array(match.titles.enumerated()), id: \.element.retailer) { index, item in
                    if index > 0 {
                        HStack(spacing: 8) {
                            Rectangle().fill(BuyWiseColors.border).frame(height: 1)
                            Image(systemName: match.comparison.isMatch ? "equal.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(match.comparison.isMatch ? BuyWiseColors.success : BuyWiseColors.error)
                            Rectangle().fill(BuyWiseColors.border).frame(height: 1)
                        }
                        .padding(.vertical, 6)
                    }
                    listingRow(item.retailer, title: item.title)
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(checklistItems, id: \.label) { item in
                    Label(item.label, systemImage: item.isTrue ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(BuyWiseTypography.captionBold)
                        .foregroundStyle(item.isTrue ? BuyWiseColors.success : BuyWiseColors.error)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Capsule().fill((item.isTrue ? BuyWiseColors.success : BuyWiseColors.error).opacity(0.1)))
                        .lineLimit(1)
                }
            }

            Text(match.comparison.isMatch
                 ? "Matched across \(storeNames), so these prices are for the same product."
                 : "These listings may not be the same product, so compare carefully.")
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textSecondary)

            if !match.rejected.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showRejected.toggle() }
                    } label: {
                        HStack {
                            Text("\(match.rejected.count) similar listing\(match.rejected.count == 1 ? "" : "s") not compared")
                                .font(BuyWiseTypography.subheadline)
                                .foregroundStyle(BuyWiseColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(BuyWiseColors.textSecondary)
                                .rotationEffect(.degrees(showRejected ? 180 : 0))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .bwSecondarySurface()
                    }
                    .buttonStyle(.plain)

                    if showRejected {
                        ForEach(match.rejected) { rejected in
                            HStack(alignment: .top, spacing: 10) {
                                RetailerLogoView(retailer: rejected.retailer, height: 12)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rejected.title)
                                        .font(BuyWiseTypography.caption)
                                        .foregroundStyle(BuyWiseColors.textPrimary)
                                        .strikethrough(color: BuyWiseColors.textSecondary)
                                    Label(rejected.reason, systemImage: "xmark.circle.fill")
                                        .font(BuyWiseTypography.captionBold)
                                        .foregroundStyle(BuyWiseColors.error)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }

            Label("Matched on your iPhone. No data leaves your device.", systemImage: "lock.shield")
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textSecondary)
        }
        .padding(18)
        .bwCard()
    }

    private var storeNames: String {
        ListFormatter.localizedString(byJoining: match.titles.map(\.retailer.rawValue))
    }

    private func listingRow(_ retailer: Retailer, title: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            RetailerLogoView(retailer: retailer, height: 14)
                .frame(width: 92, alignment: .leading)
            Text("“\(title)”")
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
