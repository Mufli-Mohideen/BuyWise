import CoreLocation

enum StoreBranches {
    static let all: [StoreBranch] = [
        StoreBranch(id: "singer-kollupitiya", retailer: .singer, branchName: "Singer Kollupitiya", address: "361 Galle Rd, Colombo 03",
                    coordinate: CLLocationCoordinate2D(latitude: 6.9147, longitude: 79.8494), opensAt: 9, closesAt: 21),
        StoreBranch(id: "abans-kollupitiya", retailer: .abans, branchName: "Abans Kollupitiya", address: "498 Galle Rd, Colombo 03",
                    coordinate: CLLocationCoordinate2D(latitude: 6.9012, longitude: 79.8548), opensAt: 9, closesAt: 20),
        StoreBranch(id: "singer-borella", retailer: .singer, branchName: "Singer Borella", address: "36 D.S. Senanayake Mw, Colombo 08",
                    coordinate: CLLocationCoordinate2D(latitude: 6.9146, longitude: 79.8775), opensAt: 9, closesAt: 20),
        StoreBranch(id: "abans-rajagiriya", retailer: .abans, branchName: "Abans Rajagiriya", address: "512 Kotte Rd, Rajagiriya",
                    coordinate: CLLocationCoordinate2D(latitude: 6.9091, longitude: 79.8938), opensAt: 9, closesAt: 20),
        StoreBranch(id: "singer-nugegoda", retailer: .singer, branchName: "Singer Nugegoda", address: "146 High Level Rd, Nugegoda",
                    coordinate: CLLocationCoordinate2D(latitude: 6.8721, longitude: 79.8890), opensAt: 9, closesAt: 21),
        StoreBranch(id: "abans-wellawatte", retailer: .abans, branchName: "Abans Wellawatte", address: "221 Galle Rd, Colombo 06",
                    coordinate: CLLocationCoordinate2D(latitude: 6.8745, longitude: 79.8606), opensAt: 9, closesAt: 20),
        StoreBranch(id: "singer-dehiwala", retailer: .singer, branchName: "Singer Dehiwala", address: "70 Galle Rd, Dehiwala",
                    coordinate: CLLocationCoordinate2D(latitude: 6.8511, longitude: 79.8653), opensAt: 9, closesAt: 21),
        StoreBranch(id: "abans-maharagama", retailer: .abans, branchName: "Abans Maharagama", address: "115 High Level Rd, Maharagama",
                    coordinate: CLLocationCoordinate2D(latitude: 6.8480, longitude: 79.9265), opensAt: 9, closesAt: 20)
    ]

    static func sortedByDistance(_ retailer: Retailer? = nil) -> [StoreBranch] {
        all.filter { retailer == nil || $0.retailer == retailer }
            .sorted { LocationProvider.shared.distance(to: $0) < LocationProvider.shared.distance(to: $1) }
    }

    static func nearest(_ retailer: Retailer) -> StoreBranch? {
        sortedByDistance(retailer).first
    }
}
