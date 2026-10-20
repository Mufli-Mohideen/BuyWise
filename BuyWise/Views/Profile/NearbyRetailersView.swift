import SwiftUI
import MapKit

struct NearbyRetailersView: View {
    var initialRetailer: Retailer? = nil
    var focusProduct: Product? = nil

    @State private var retailerFilter: Retailer?
    @State private var selectedID: String?
    @State private var position: MapCameraPosition = .automatic
    @State private var route: MKRoute?
    @State private var isRouting = false

    private var location: LocationProvider { .shared }
    private var branches: [StoreBranch] { StoreBranches.sortedByDistance(retailerFilter) }
    private var selectedBranch: StoreBranch? { StoreBranches.all.first { $0.id == selectedID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                filterBar
                map
                if let selectedBranch {
                    SelectedBranchCard(
                        branch: selectedBranch,
                        product: focusProduct,
                        route: route,
                        isRouting: isRouting,
                        onDirections: { openDirections(to: selectedBranch) }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                branchList
            }
            .padding(20)
        }
        .bwScreenBackground()
        .navigationTitle("Nearby Stores")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            location.start()
            if retailerFilter == nil { retailerFilter = initialRetailer }
            if selectedID == nil { select(branches.first, animated: false) }
        }
        .onChange(of: retailerFilter) { _, _ in
            select(branches.first, animated: true)
        }
        .onChange(of: selectedID) { _, _ in
            Task { await calculateRoute() }
        }
        .onChange(of: location.deviceLocation) { _, _ in
            select(branches.first, animated: true)
            Task { await calculateRoute() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stores near you")
                .font(BuyWiseTypography.titleXL)
                .foregroundStyle(BuyWiseColors.textPrimary)
            Label(location.statusText, systemImage: location.isUsingDemoLocation ? "location.slash" : "location.fill")
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textSecondary)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All stores", retailer: nil)
                ForEach(Retailer.allCases) { retailer in
                    filterChip(title: retailer.rawValue, retailer: retailer)
                }
            }
        }
        .scrollClipDisabled()
    }

    private func filterChip(title: String, retailer: Retailer?) -> some View {
        let isSelected = retailerFilter == retailer
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { retailerFilter = retailer }
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

    private var map: some View {
        Map(position: $position, selection: $selectedID) {
            Annotation("You", coordinate: location.effectiveLocation.coordinate) {
                ZStack {
                    Circle().fill(BuyWiseColors.brand.opacity(0.2)).frame(width: 34, height: 34)
                    Circle().fill(BuyWiseColors.brand).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2.5))
                }
            }
            ForEach(branches) { branch in
                Annotation(branch.branchName, coordinate: branch.coordinate) {
                    RetailerMapPin(retailer: branch.retailer, isSelected: branch.id == selectedID)
                }
                .tag(branch.id)
            }
            if let route {
                MapPolyline(route.polyline)
                    .stroke(BuyWiseColors.brand, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls { MapCompass() }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: BuyWiseTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BuyWiseTheme.cardRadius, style: .continuous)
                .strokeBorder(BuyWiseColors.border, lineWidth: 1)
        )
    }

    private var branchList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "\(branches.count) stores", subtitle: "Sorted by distance from you")
            ForEach(Array(branches.enumerated()), id: \.element.id) { index, branch in
                Button {
                    select(branch, animated: true)
                } label: {
                    StoreBranchRow(branch: branch, rank: index + 1, isSelected: branch.id == selectedID)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private func select(_ branch: StoreBranch?, animated: Bool) {
        guard let branch else { return }
        let update = {
            selectedID = branch.id
            position = .region(region(containing: [location.effectiveLocation.coordinate, branch.coordinate]))
        }
        if animated { withAnimation(.easeInOut(duration: 0.35), update) } else { update() }
    }

    private func region(containing coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 2.6, 0.02),
            longitudeDelta: max((lons.max()! - lons.min()!) * 2.6, 0.02)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private func calculateRoute() async {
        guard let branch = selectedBranch else { return }
        route = nil
        isRouting = true
        defer { isRouting = false }

        let request = MKDirections.Request()
        request.source = MKMapItem(location: location.effectiveLocation, address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: branch.coordinate.latitude, longitude: branch.coordinate.longitude), address: nil)
        request.transportType = .automobile

        do {
            let response = try await MKDirections(request: request).calculate()
            guard branch.id == selectedID, let first = response.routes.first else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                route = first
                let bounds = first.polyline.boundingMapRect
                position = .rect(bounds.insetBy(dx: -bounds.width * 0.35, dy: -bounds.height * 0.35))
            }
        } catch {
            // Routing unavailable here; the card shows an estimate instead.
        }
    }

    private func openDirections(to branch: StoreBranch) {
        let item = MKMapItem(location: CLLocation(latitude: branch.coordinate.latitude, longitude: branch.coordinate.longitude), address: nil)
        item.name = branch.branchName
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

private struct SelectedBranchCard: View {
    let branch: StoreBranch
    let product: Product?
    let route: MKRoute?
    let isRouting: Bool
    let onDirections: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 48, height: 48)
                    .overlay(Image(branch.retailer.logoAssetName).resizable().scaledToFit().padding(8))
                    .overlay(Circle().strokeBorder(BuyWiseColors.border, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(branch.branchName)
                        .font(BuyWiseTypography.headline)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                    Text(branch.address)
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                metric(symbol: "location.north.line", title: "Distance", value: DistanceFormatter.string(LocationProvider.shared.distance(to: branch)))
                metric(symbol: "car.fill", title: route == nil && !isRouting ? "Est. drive" : "Drive", value: driveText)
                metric(symbol: "clock", title: branch.statusText, value: branch.shortHoursText,
                       tint: branch.isOpenNow ? BuyWiseColors.success : branch.hasHours ? BuyWiseColors.error : BuyWiseColors.textSecondary)
            }

            if let product, let listing = product.listing(for: branch.retailer) {
                HStack(spacing: 10) {
                    ProductImageView(product: product, cornerRadius: 8)
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(product.name)
                            .font(BuyWiseTypography.captionBold)
                            .foregroundStyle(BuyWiseColors.textPrimary)
                        Text("\(PriceFormatter.lkr(listing.price)) at \(branch.retailer.rawValue)")
                            .font(BuyWiseTypography.caption)
                            .foregroundStyle(BuyWiseColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(10)
                .bwSecondarySurface()
            }

            PrimaryButton(title: "Get directions", symbolName: "arrow.triangle.turn.up.right.diamond.fill", action: onDirections)
        }
        .padding(16)
        .bwCard()
    }

    private var driveText: String {
        if let route {
            let minutes = max(1, Int((route.expectedTravelTime / 60).rounded()))
            return "\(minutes) min · \(DistanceFormatter.string(route.distance))"
        }
        if isRouting { return "Calculating…" }
        // Apple Maps routing isn't available everywhere, so estimate from straight-line distance.
        let roadKm = LocationProvider.shared.distance(to: branch) / 1000 * 1.35
        let minutes = max(2, Int((roadKm / 22 * 60).rounded()))
        return "~\(minutes) min"
    }

    private func metric(symbol: String, title: String, value: String, tint: Color = BuyWiseColors.brand) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(BuyWiseTypography.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(BuyWiseTypography.captionBold)
                .foregroundStyle(BuyWiseColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .bwSecondarySurface()
    }
}

struct RetailerMapPin: View {
    let retailer: Retailer
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.white)
                .frame(width: isSelected ? 46 : 34, height: isSelected ? 46 : 34)
                .overlay(
                    Image(retailer.logoAssetName)
                        .resizable()
                        .scaledToFit()
                        .padding(isSelected ? 7 : 5)
                )
                .overlay(Circle().strokeBorder(BuyWiseColors.brand, lineWidth: isSelected ? 3 : 2))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            Triangle()
                .fill(BuyWiseColors.brand)
                .frame(width: 8, height: 6)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}

private struct StoreBranchRow: View {
    let branch: StoreBranch
    let rank: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(branch.retailer.logoAssetName)
                        .resizable()
                        .scaledToFit()
                        .padding(7)
                )
                .overlay(Circle().strokeBorder(BuyWiseColors.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(branch.branchName)
                    .font(BuyWiseTypography.subheadline)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                Text(branch.address)
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
                    .lineLimit(1)
                Label(branch.hoursText, systemImage: "circle.fill")
                    .font(BuyWiseTypography.caption)
                    .labelStyle(StatusDotLabelStyle())
                    .foregroundStyle(branch.isOpenNow ? BuyWiseColors.success : branch.hasHours ? BuyWiseColors.error : BuyWiseColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(DistanceFormatter.string(LocationProvider.shared.distance(to: branch)))
                    .font(BuyWiseTypography.priceSmall)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                Text(rank == 1 ? "Nearest" : "away")
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(rank == 1 ? BuyWiseColors.brand : BuyWiseColors.textSecondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                .fill(isSelected ? BuyWiseColors.brandSoft : BuyWiseColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                .strokeBorder(isSelected ? BuyWiseColors.brand.opacity(0.5) : BuyWiseColors.border, lineWidth: 1)
        )
    }
}

private struct StatusDotLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 6))
            configuration.title
        }
    }
}
