import SwiftUI
import PhotosUI

struct ImageScannerSheetView: View {
    var onProductIdentified: (Product) -> Void

    private enum Phase {
        case choose
        case analyzing(UIImage)
        case identified(IdentificationResult, UIImage, [String])
        case failed(String, UIImage?)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .choose
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var scanLine: CGFloat = -1

    private var samples: [Product] {
        ProductCatalog.featuredTrio + ProductCatalog.featured(.smartphones, count: 2).dropFirst()
    }

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
                    await analyze(image)
                }
                photoItem = nil
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in Task { await analyze(image) } }
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .choose:
            chooseView
        case .analyzing(let image):
            analyzingView(image)
        case .identified(let result, let image, let lines):
            ScrollView {
                ScanResultView(
                    result: result,
                    sourceImage: image,
                    recognisedLines: lines,
                    onViewProduct: onProductIdentified,
                    onScanAgain: { withAnimation { phase = .choose } }
                )
                .padding(20)
                .padding(.top, 20)
            }
        case .failed(let message, let image):
            failedView(message, image: image)
        }
    }

    private var chooseView: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                ViewfinderCorners()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 250, height: 180)
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
            }
            VStack(spacing: 6) {
                Text("Scan a product or price tag")
                    .font(BuyWiseTypography.title)
                    .foregroundStyle(.white)
                Text("BuyWise reads the text on the photo on your iPhone and finds the matching product.")
                    .font(BuyWiseTypography.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Text("Try a sample price tag")
                    .font(BuyWiseTypography.captionBold)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 24)
                SampleProductChips(products: samples) { product in
                    Task { await analyze(SampleImages.priceTag(for: product)) }
                }
            }

            VStack(spacing: 12) {
                if CameraPicker.isAvailable {
                    PrimaryButton(title: "Take a photo", symbolName: "camera.fill") { showCamera = true }
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose from Photos").font(BuyWiseTypography.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                            .fill(CameraPicker.isAvailable ? Color.white.opacity(0.14) : BuyWiseColors.brand)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private func analyzingView(_ image: UIImage) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(LinearGradient(colors: [.clear, BuyWiseColors.brand.opacity(0.9), .clear], startPoint: .top, endPoint: .bottom))
                            .frame(height: 36)
                            .offset(y: (scanLine + 1) / 2 * (proxy.size.height - 36))
                            .shadow(color: BuyWiseColors.brand, radius: 8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 24)
                .onAppear {
                    scanLine = -1
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { scanLine = 1 }
                }
            HStack(spacing: 10) {
                ProgressView().tint(.white)
                Text("Reading text…")
                    .font(BuyWiseTypography.headline)
                    .foregroundStyle(.white)
            }
            Spacer()
        }
    }

    private func failedView(_ message: String, image: UIImage?) -> some View {
        VStack(spacing: 18) {
            Spacer()
            if let image {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .opacity(0.6)
            }
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(BuyWiseColors.warning)
            Text("No match found")
                .font(BuyWiseTypography.title)
                .foregroundStyle(.white)
            Text(message)
                .font(BuyWiseTypography.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            PrimaryButton(title: "Try again", symbolName: "arrow.counterclockwise") { withAnimation { phase = .choose } }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
    }

    private func analyze(_ image: UIImage) async {
        withAnimation { phase = .analyzing(image) }
        let started = Date()
        do {
            let lines = try await VisionScanner.recognizeText(in: image)
            let result = try await ProductIdentifier.identify(text: lines.joined(separator: " "), method: .text)
            await minimumDelay(since: started)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                phase = .identified(result, image, lines)
            }
        } catch {
            await minimumDelay(since: started)
            let message = (error as? IdentificationError)?.errorDescription ?? "Try a clearer photo of the product name or price tag."
            withAnimation { phase = .failed(message, image) }
        }
    }

    /// Keeps the scanning state on screen briefly so the step is visible.
    private func minimumDelay(since start: Date) async {
        let remaining = 1.2 - Date().timeIntervalSince(start)
        if remaining > 0 { try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) }
    }
}

struct ViewfinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let length: CGFloat = 32
        var path = Path()
        for (corner, dx, dy) in [(CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0), (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                                 (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0), (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0)] {
            path.move(to: CGPoint(x: corner.x, y: corner.y + dy * length))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x + dx * length, y: corner.y))
        }
        return path
    }
}
