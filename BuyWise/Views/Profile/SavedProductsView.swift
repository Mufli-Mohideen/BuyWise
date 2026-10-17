import SwiftUI

struct SavedProductsView: View {
    @EnvironmentObject private var appState: AppState

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            if appState.savedProducts.isEmpty {
                EmptyStateView(symbolName: "heart", title: "No saved products", subtitle: "Tap the heart icon on any product to save it here.")
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(appState.savedProducts) { product in
                        NavigationLink(value: product) {
                            CompactProductCard(product: product)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(20)
            }
        }
        .bwScreenBackground()
        .navigationTitle("Saved Products")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
    }
}
