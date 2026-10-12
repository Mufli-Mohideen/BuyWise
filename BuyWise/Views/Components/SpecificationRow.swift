import SwiftUI

struct SpecificationRow: View {
    let specification: Specification

    private var symbolName: String {
        switch specification.label {
        case "Driver": return "waveform"
        case "Battery": return "battery.100"
        case "Weight": return "scalemass"
        case "Connectivity": return "antenna.radiowaves.left.and.right"
        case "Noise Cancellation": return "ear.badge.waveform"
        case "Display": return "rectangle.inset.filled"
        case "Chip": return "cpu"
        case "Storage": return "internaldrive"
        case "Camera": return "camera"
        case "5G": return "antenna.radiowaves.left.and.right"
        case "Memory": return "memorychip"
        default: return "info.circle"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BuyWiseColors.brand)
                .frame(width: 30, height: 30)
                .background(Circle().fill(BuyWiseColors.brandSoft))

            Text(specification.label)
                .font(BuyWiseTypography.subheadline)
                .foregroundStyle(BuyWiseColors.textPrimary)

            Spacer()

            Text(specification.value)
                .font(BuyWiseTypography.subheadline)
                .foregroundStyle(BuyWiseColors.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .bwSecondarySurface()
    }
}
