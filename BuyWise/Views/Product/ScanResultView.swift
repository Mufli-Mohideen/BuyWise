import SwiftUI

/// Shared result panel for barcode, photo (OCR) and URL identification.
struct ScanResultView: View {
    let result: IdentificationResult
    var sourceImage: UIImage? = nil
    var recognisedLines: [String] = []
    let onViewProduct: (Product) -> Void
    let onScanAgain: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(BuyWiseColors.success)
                Text("Product identified")
                    .font(BuyWiseTypography.headline)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                Spacer()
                Text(result.method.rawValue)
                    .font(BuyWiseTypography.captionBold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(BuyWiseColors.brandSoft))
                    .foregroundStyle(BuyWiseColors.brand)
            }

            HStack(spacing: 14) {
                ProductImageView(product: result.product, cornerRadius: BuyWiseTheme.smallRadius)
                    .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.product.brand.uppercased())
                        .font(BuyWiseTypography.captionBold)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                    Text(result.product.name)
                        .font(BuyWiseTypography.title)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                    Text("From \(PriceFormatter.lkr(result.product.startingPrice))")
                        .font(BuyWiseTypography.priceMedium)
                        .foregroundStyle(BuyWiseColors.brand)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Match confidence")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                    Spacer()
                    Text("\(Int((result.confidence * 100).rounded()))%")
                        .font(BuyWiseTypography.captionBold)
                        .foregroundStyle(BuyWiseColors.success)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(BuyWiseColors.surfaceSecondary)
                        Capsule().fill(BuyWiseColors.success)
                            .frame(width: proxy.size.width * (appeared ? result.confidence : 0))
                    }
                }
                .frame(height: 6)
            }

            if !recognisedLines.isEmpty || sourceImage != nil {
                evidence
            } else {
                HStack {
                    Image(systemName: result.method == .barcode ? "barcode" : "link")
                        .foregroundStyle(BuyWiseColors.textSecondary)
                    Text(result.evidence)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(BuyWiseColors.textSecondary)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(12)
                .bwSecondarySurface()
            }

            VStack(spacing: 10) {
                PrimaryButton(title: "View product", symbolName: "arrow.right") { onViewProduct(result.product) }
                SecondaryButton(title: "Scan something else", symbolName: "arrow.counterclockwise", action: onScanAgain)
            }
        }
        .padding(18)
        .bwCard()
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.15)) { appeared = true }
        }
    }

    private var evidence: some View {
        HStack(alignment: .top, spacing: 12) {
            if let sourceImage {
                Image(uiImage: sourceImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 74)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(result.method == .barcode ? "Barcode read" : "Text we read")
                    .font(BuyWiseTypography.captionBold)
                    .foregroundStyle(BuyWiseColors.textSecondary)
                ForEach(Array((recognisedLines.isEmpty ? [result.evidence] : recognisedLines).prefix(5).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(BuyWiseColors.textPrimary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .bwSecondarySurface()
    }
}

/// Camera capture via UIImagePickerController (real devices only).
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Small product picker used by the sample-image demos.
struct SampleProductChips: View {
    let products: [Product]
    let onPick: (Product) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(products) { product in
                    Button { onPick(product) } label: {
                        HStack(spacing: 8) {
                            ProductImageView(product: product, cornerRadius: 6)
                                .frame(width: 28, height: 28)
                            Text(product.name)
                                .font(BuyWiseTypography.captionBold)
                                .foregroundStyle(.white)
                        }
                        .padding(.leading, 6)
                        .padding(.trailing, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, 24)
        }
    }
}
