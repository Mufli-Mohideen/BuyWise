import SwiftUI

enum IdentifySheet: Int, Identifiable {
    case barcode, image, url
    var id: Int { rawValue }
}

struct IdentifyProductView: View {
    var onProductIdentified: (Product) -> Void

    @State private var activeSheet: IdentifySheet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Identify a product")
                        .font(BuyWiseTypography.titleXL)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                    Text("Choose how you want to find it.")
                        .font(BuyWiseTypography.body)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
                .padding(.bottom, 4)

                NavigationLink {
                    SearchView()
                } label: {
                    IdentifyOptionRow(title: "Search by name", subtitle: "Type the product you're looking for", symbolName: "magnifyingglass")
                }
                .buttonStyle(PressableButtonStyle())

                Button { activeSheet = .barcode } label: {
                    IdentifyOptionRow(title: "Scan barcode", subtitle: "Scan the barcode on the box", symbolName: "barcode.viewfinder")
                }
                .buttonStyle(PressableButtonStyle())

                Button { activeSheet = .image } label: {
                    IdentifyOptionRow(title: "Scan a photo or price tag", subtitle: "We read the text on the photo", symbolName: "text.viewfinder")
                }
                .buttonStyle(PressableButtonStyle())

                Button { activeSheet = .url } label: {
                    IdentifyOptionRow(title: "Paste a product link", subtitle: "From Celltronics, Abans or Singer", symbolName: "link")
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(20)
        }
        .navigationTitle("Identify")
        .navigationBarTitleDisplayMode(.inline)
        .bwScreenBackground()
        .identifySheets($activeSheet, onIdentified: onProductIdentified)
    }
}

extension View {
    /// Presents the barcode / photo / link identification sheets and reports the identified product.
    func identifySheets(_ sheet: Binding<IdentifySheet?>, onIdentified: @escaping (Product) -> Void) -> some View {
        self.sheet(item: sheet) { kind in
            let finish: (Product) -> Void = { product in
                sheet.wrappedValue = nil
                Task {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    onIdentified(product)
                }
            }
            switch kind {
            case .barcode: BarcodeScannerSheetView(onProductIdentified: finish)
            case .image: ImageScannerSheetView(onProductIdentified: finish)
            case .url: PasteURLSheetView(onIdentify: finish)
            }
        }
    }
}
