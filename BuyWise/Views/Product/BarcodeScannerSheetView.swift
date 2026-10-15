import SwiftUI
import PhotosUI
import VisionKit
import Vision

struct BarcodeScannerSheetView: View {
    var onProductIdentified: (Product) -> Void

    private enum Phase {
        case scanning
        case reading(UIImage?)
        case identified(IdentificationResult, UIImage?)
        case failed(String)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .scanning
    @State private var photoItem: PhotosPickerItem?
    @State private var scanLineOffset: CGFloat = -70

    private let samples = [ProductCatalog.jblLive770NC, ProductCatalog.pixel9, ProductCatalog.boseQCUltra, ProductCatalog.pavilion14]
    private var liveScanningSupported: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                content
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.tint(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await read(image)
                }
                photoItem = nil
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .scanning:
            scanningView
        case .reading(let image):
            VStack(spacing: 20) {
                if let image {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 24)
                }
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Reading barcode…").font(BuyWiseTypography.headline).foregroundStyle(.white)
                }
            }
        case .identified(let result, let image):
            ScrollView {
                ScanResultView(result: result, sourceImage: image, recognisedLines: [result.evidence],
                               onViewProduct: onProductIdentified,
                               onScanAgain: { withAnimation { phase = .scanning } })
                    .padding(20)
                    .padding(.top, 20)
            }
        case .failed(let message):
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "barcode.viewfinder").font(.system(size: 44)).foregroundStyle(BuyWiseColors.warning)
                Text("Barcode not recognised").font(BuyWiseTypography.title).foregroundStyle(.white)
                Text(message).font(BuyWiseTypography.body).foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
                Spacer()
                PrimaryButton(title: "Try again", symbolName: "arrow.counterclockwise") { withAnimation { phase = .scanning } }
                    .padding(.horizontal, 24).padding(.bottom, 16)
            }
        }
    }

    private var scanningView: some View {
        VStack(spacing: 22) {
            if liveScanningSupported {
                LiveBarcodeScanner { payload in
                    Task { await identify(payload: payload, image: nil) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    ViewfinderCorners()
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .padding(30)
                )
                .frame(height: 360)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                Text("Point your camera at the product barcode")
                    .font(BuyWiseTypography.subheadline)
                    .foregroundStyle(.white)
            } else {
                Spacer()
                ZStack {
                    ViewfinderCorners()
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 260, height: 170)
                    Image(systemName: "barcode")
                        .font(.system(size: 70, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.35))
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, BuyWiseColors.brand, .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 230, height: 3)
                        .shadow(color: BuyWiseColors.brand, radius: 6)
                        .offset(y: scanLineOffset)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { scanLineOffset = 70 }
                }
                VStack(spacing: 6) {
                    Text("Scan a barcode")
                        .font(BuyWiseTypography.title)
                        .foregroundStyle(.white)
                    Text("Live camera scanning needs an iPhone camera. Try a sample barcode or pick a photo of one.")
                        .font(BuyWiseTypography.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Text("Try a sample barcode")
                    .font(BuyWiseTypography.captionBold)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 24)
                SampleProductChips(products: samples) { product in
                    Task { await read(SampleImages.barcode(for: product)) }
                }
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                    Text("Choose a photo of a barcode").font(BuyWiseTypography.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .background(RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous).fill(Color.white.opacity(0.14)))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private func read(_ image: UIImage) async {
        withAnimation { phase = .reading(image) }
        do {
            let payloads = try await VisionScanner.detectBarcodes(in: image)
            try? await Task.sleep(nanoseconds: 700_000_000)
            await identify(payload: payloads[0], image: image)
        } catch {
            withAnimation { phase = .failed((error as? IdentificationError)?.errorDescription ?? "We couldn't read a barcode in this image. Try a clearer, closer photo.") }
        }
    }

    private func identify(payload: String, image: UIImage?) async {
        do {
            let result = try ProductIdentifier.identify(barcode: payload)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { phase = .identified(result, image) }
        } catch {
            withAnimation { phase = .failed("Barcode \(payload) isn't in the Singer or Abans catalogue yet.") }
        }
    }
}

/// Live barcode scanning with VisionKit's DataScannerViewController (real devices).
private struct LiveBarcodeScanner: UIViewControllerRepresentable {
    let onBarcode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onBarcode: onBarcode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcode: (String) -> Void
        private var handled = false

        init(onBarcode: @escaping (String) -> Void) { self.onBarcode = onBarcode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !handled else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    handled = true
                    dataScanner.stopScanning()
                    onBarcode(payload)
                    return
                }
            }
        }
    }
}
