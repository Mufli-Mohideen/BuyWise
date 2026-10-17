import SwiftUI

struct SearchHistoryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            if appState.recentSearches.isEmpty {
                EmptyStateView(symbolName: "clock.arrow.circlepath", title: "No search history", subtitle: "Products you search for will appear here.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.recentSearches.enumerated()), id: \.element) { index, term in
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(BuyWiseColors.textSecondary)
                            Text(term)
                                .font(BuyWiseTypography.body)
                                .foregroundStyle(BuyWiseColors.textPrimary)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)

                        if index < appState.recentSearches.count - 1 {
                            Divider().overlay(BuyWiseColors.border).padding(.leading, 40)
                        }
                    }
                }
                .bwCard()
                .padding(20)
            }
        }
        .bwScreenBackground()
        .navigationTitle("Search History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !appState.recentSearches.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { appState.clearRecentSearches() }
                        .foregroundStyle(BuyWiseColors.brand)
                }
            }
        }
    }
}
