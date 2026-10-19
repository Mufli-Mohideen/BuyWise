import SwiftUI

struct PasteURLSheetView: View {
    var onIdentify: (Product) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var result: IdentificationResult?
    @State private var errorMessage: String?
    @State private var isWorking = false
    @FocusState private var fieldFocused: Bool

    /// Real product links from the catalogue, cycling through the retailers.
    private var examples: [(label: String, url: String)] {
        ProductCatalog.featuredTrio.enumerated().compactMap { index, product in
            let preferred = Retailer.allCases[index % Retailer.allCases.count]
            guard let listing = product.listing(for: preferred) ?? product.listings.first,
                  let url = listing.url else { return nil }
            return ("\(listing.retailer.rawValue) · \(product.name)", url.absoluteString)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Paste a product link")
                            .font(BuyWiseTypography.titleXL)
                            .foregroundStyle(BuyWiseColors.textPrimary)
                        Text("Paste a Celltronics, Abans or Singer product link and we'll compare it across the stores.")
                            .font(BuyWiseTypography.body)
                            .foregroundStyle(BuyWiseColors.textSecondary)
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "link")
                            .foregroundStyle(BuyWiseColors.textSecondary)
                        TextField("https://celltronics.lk/product/…", text: $urlText, axis: .vertical)
                            .lineLimit(1...3)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .font(BuyWiseTypography.body)
                            .focused($fieldFocused)
                        if !urlText.isEmpty {
                            Button { urlText = ""; result = nil; errorMessage = nil } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(BuyWiseColors.textSecondary)
                            }
                        } else {
                            Button("Paste") {
                                if let text = UIPasteboard.general.string { urlText = text }
                            }
                            .font(BuyWiseTypography.captionBold)
                            .foregroundStyle(BuyWiseColors.brand)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous).fill(BuyWiseColors.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                            .strokeBorder(errorMessage == nil ? BuyWiseColors.border : BuyWiseColors.error, lineWidth: 1)
                    )

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(BuyWiseTypography.caption)
                            .foregroundStyle(BuyWiseColors.error)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Try an example")
                            .font(BuyWiseTypography.captionBold)
                            .foregroundStyle(BuyWiseColors.textSecondary)
                        ForEach(examples, id: \.url) { example in
                            Button {
                                urlText = example.url
                                errorMessage = nil
                                result = nil
                            } label: {
                                HStack {
                                    Image(systemName: "link.circle.fill").foregroundStyle(BuyWiseColors.brand)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(example.label).font(BuyWiseTypography.captionBold).foregroundStyle(BuyWiseColors.textPrimary)
                                        Text(example.url).font(BuyWiseTypography.caption).foregroundStyle(BuyWiseColors.textSecondary).lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .bwSecondarySurface()
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 8) {
                        ForEach(Retailer.allCases) { RetailerLogoView(retailer: $0, height: 16) }
                        Text("Supported stores")
                            .font(BuyWiseTypography.caption)
                            .foregroundStyle(BuyWiseColors.textSecondary)
                    }

                    if let result {
                        ScanResultView(result: result, onViewProduct: onIdentify, onScanAgain: {
                            withAnimation { self.result = nil; urlText = "" }
                        })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        PrimaryButton(title: "Find product", symbolName: "magnifyingglass", isLoading: isWorking,
                                      isEnabled: !urlText.trimmingCharacters(in: .whitespaces).isEmpty, action: identify)
                    }
                }
                .padding(20)
            }
            .bwScreenBackground()
            .navigationTitle("Paste link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func identify() {
        fieldFocused = false
        isWorking = true
        errorMessage = nil
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            do {
                let found = try await ProductIdentifier.identify(url: urlText)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { result = found }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "That link couldn't be read."
            }
            isWorking = false
        }
    }
}
