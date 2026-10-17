import UIKit
import Vision
import CoreImage.CIFilterBuiltins

/// On-device Vision OCR and barcode detection.
enum VisionScanner {
    nonisolated static func recognizeText(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw IdentificationError.noTextFound }
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let observations = try await request.perform(on: cgImage, orientation: image.cgOrientation)
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        guard !lines.isEmpty else { throw IdentificationError.noTextFound }
        return lines
    }

    nonisolated static func detectBarcodes(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw IdentificationError.noBarcodeFound }
        var request = DetectBarcodesRequest()
        request.symbologies = [.ean13, .ean8, .upce, .code128, .qr]
        var payloads: [String] = []
        do {
            let observations = try await request.perform(on: cgImage, orientation: image.cgOrientation)
            payloads = observations.compactMap(\.payloadString)
        } catch {
            // The latest detector revision isn't available everywhere (e.g. the Simulator);
            // fall back to the original Vision barcode detector.
            payloads = try legacyBarcodes(in: cgImage, orientation: image.cgOrientation)
        }
        guard !payloads.isEmpty else { throw IdentificationError.noBarcodeFound }
        return payloads
    }

    nonisolated private static func legacyBarcodes(in cgImage: CGImage, orientation: CGImagePropertyOrientation) throws -> [String] {
        let request = VNDetectBarcodesRequest()
        request.revision = VNDetectBarcodesRequestRevision1
        request.symbologies = [.ean13, .ean8, .upce, .code128, .qr]
        try VNImageRequestHandler(cgImage: cgImage, orientation: orientation).perform([request])
        return (request.results ?? []).compactMap(\.payloadStringValue)
    }
}

/// Sample images for trying the scanners without a camera (e.g. in the Simulator).
/// They are real rendered images that go through the same Vision pipeline as photos.
enum SampleImages {
    static func priceTag(for product: Product) -> UIImage {
        let size = CGSize(width: 900, height: 560)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(white: 0.96, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let card = CGRect(x: 40, y: 40, width: size.width - 80, height: size.height - 80)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: card, cornerRadius: 28).fill()
            UIColor(red: 1, green: 0.42, blue: 0, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: card.minX, y: card.minY, width: card.width, height: 90), byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 28, height: 28)).fill()

            draw("IN-STORE PRICE", at: CGPoint(x: card.minX + 36, y: card.minY + 26), font: .systemFont(ofSize: 32, weight: .heavy), color: .white)
            draw(product.brand.uppercased(), at: CGPoint(x: card.minX + 36, y: card.minY + 124), font: .systemFont(ofSize: 34, weight: .semibold), color: .darkGray)
            let textWidth = card.width - 72
            let nameFont: UIFont = .systemFont(ofSize: product.name.count > 18 ? 42 : 60, weight: .bold)
            (product.name as NSString).draw(
                with: CGRect(x: card.minX + 36, y: card.minY + 168, width: textWidth, height: 104),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: [.font: nameFont, .foregroundColor: UIColor.black],
                context: nil
            )
            draw(product.tagline.isEmpty ? product.keySpec : product.tagline, at: CGPoint(x: card.minX + 36, y: card.minY + 276),
                 font: .systemFont(ofSize: 26, weight: .regular), color: .darkGray)
            draw(PriceFormatter.lkr(product.highestListing.price), at: CGPoint(x: card.minX + 36, y: card.minY + 318), font: .systemFont(ofSize: 72, weight: .heavy), color: .black)
        }
    }

    static func barcode(for product: Product) -> UIImage {
        let size = CGSize(width: 900, height: 520)
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(product.barcode.utf8)
        filter.quietSpace = 12
        let context = CIContext()
        let barcodeImage = filter.outputImage
            .map { $0.transformed(by: CGAffineTransform(scaleX: 5, y: 5)) }
            .flatMap { context.createCGImage($0, from: $0.extent) }

        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            draw("\(product.brand) \(product.name)", at: CGPoint(x: 60, y: 40), font: .systemFont(ofSize: 34, weight: .semibold), color: .black)
            if let barcodeImage {
                let barcode = UIImage(cgImage: barcodeImage)
                let width = size.width - 120
                let height = min(300, width * barcode.size.height / barcode.size.width)
                barcode.draw(in: CGRect(x: 60, y: 110, width: width, height: height))
            }
            draw(product.barcode, at: CGPoint(x: 60, y: 440), font: .monospacedDigitSystemFont(ofSize: 40, weight: .medium), color: .black)
        }
    }

    private static func draw(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
    }
}

extension UIImage {
    nonisolated var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
