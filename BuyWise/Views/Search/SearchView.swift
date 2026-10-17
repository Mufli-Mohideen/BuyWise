import SwiftUI

private enum SortOption: String, CaseIterable {
    case relevance = "Relevance"
    case priceLowHigh = "Price: Low to High"
    case priceHighLow = "Price: High to Low"
    case value = "Value Score"
}

struct SearchView: View {
    var initialCategory: ProductCategory? = nil

    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var selectedCategory: ProductCategory?
    @State private var sortOption: SortOption = .relevance
    @FocusState private var isSearchFocused: Bool

    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    private var results: [Product] {
        var products = ProductCatalog.all.filter { product in
            let matchesCategory = selectedCategory == nil || product.category == selectedCategory
            let haystack = "\(product.fullName) \(product.category.rawValue)"
            let matchesText = !isSearching
                || searchText.split(separator: " ").allSatisfy { haystack.localizedCaseInsensitiveContains($0) }
            return matchesCategory && matchesText
        }
        switch sortOption {
        case .relevance: break
        case .priceLowHigh: products.sort { $0.startingPrice < $1.startingPrice }
        case .priceHighLow: products.sort { $0.startingPrice > $1.startingPrice }
        case .value: products.sort { $0.valueScore.overall > $1.valueScore.overall }
        }
        return products
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Search BuyWise")
                    .font(BuyWiseTypography.titleXL)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                SearchBar(placeholder: "iPhone, MacBook, headphones...", text: $searchText, onSubmit: {
                    appState.addRecentSearch(searchText)
                })
                .focused($isSearchFocused)
                .padding(.horizontal, 20)

                if isSearching || selectedCategory != nil {
                    filterBar
                    resultsList
                } else {
                    prelude
                }
            }
            .padding(.bottom, 24)
        }
        .bwScreenBackground()
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let initialCategory, selectedCategory == nil { selectedCategory = initialCategory }
        }
    }

    private var filterBar: some View {
        HStack {
            categoryShortcuts
            Spacer()
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        if sortOption == option {
                            Label(option.rawValue, systemImage: "checkmark")
                        } else {
                            Text(option.rawValue)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(BuyWiseColors.brand)
            }
            .padding(.trailing, 20)
        }
    }

    private var resultsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(results) { product in
                NavigationLink(value: product) {
                    SearchResultRow(product: product)
                }
                .buttonStyle(PressableButtonStyle())
            }

            if results.isEmpty {
                EmptyStateView(symbolName: "magnifyingglass", title: "No products found", subtitle: "Try a different name or category.")
            }
        }
        .padding(.horizontal, 20)
    }

    private var prelude: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !appState.recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionHeader(title: "Recent Searches")
                        Spacer()
                        Button("Clear") { appState.clearRecentSearches() }
                            .font(BuyWiseTypography.caption)
                            .foregroundStyle(BuyWiseColors.textSecondary)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(appState.recentSearches.enumerated()), id: \.element) { index, term in
                            Button {
                                searchText = term
                            } label: {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundStyle(BuyWiseColors.textSecondary)
                                    Text(term)
                                        .font(BuyWiseTypography.body)
                                        .foregroundStyle(BuyWiseColors.textPrimary)
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .font(.system(size: 12))
                                        .foregroundStyle(BuyWiseColors.textSecondary)
                                }
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)

                            if index < appState.recentSearches.count - 1 {
                                Divider().overlay(BuyWiseColors.border)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .bwCard()
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Popular Categories")
                categoryShortcuts
            }
        }
        .padding(.horizontal, 20)
    }

    private var categoryShortcuts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryChip(title: "All", category: nil)
                ForEach(ProductCategory.allCases) { category in
                    categoryChip(title: category.rawValue, category: category)
                }
            }
        }
    }

    private func categoryChip(title: String, category: ProductCategory?) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
        } label: {
            Text(title)
                .font(BuyWiseTypography.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(isSelected ? BuyWiseColors.brand : BuyWiseColors.surface))
                .overlay(Capsule().strokeBorder(isSelected ? .clear : BuyWiseColors.border, lineWidth: 1))
                .foregroundStyle(isSelected ? .white : BuyWiseColors.textPrimary)
        }
        .buttonStyle(.plain)
    }
}
