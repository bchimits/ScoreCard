import Foundation
import MapKit
import CoreLocation
import Combine

@MainActor
final class CourseSearchService: NSObject, ObservableObject {

    @Published var nearbyCourses: [CourseResult] = []
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isSearching = false
    @Published var locationError: String?

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = locationManager.authorizationStatus
    }

    func findNearbyCourses() async {
        isSearching = true
        locationError = nil
        defer { isSearching = false }

        do {
            let location = try await requestLocation()
            await searchCourses(near: location)
        } catch {
            locationError = error.localizedDescription
        }
    }

    private func requestLocation() async throws -> CLLocation {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // Wait briefly for the authorization callback then try again
            try await Task.sleep(nanoseconds: 1_500_000_000)
            fallthrough
        case .authorizedWhenInUse, .authorizedAlways:
            return try await withCheckedThrowingContinuation { cont in
                self.locationContinuation = cont
                locationManager.requestLocation()
            }
        case .denied, .restricted:
            throw LocationError.denied
        @unknown default:
            throw LocationError.denied
        }
    }

    private func searchCourses(near location: CLLocation) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "golf course"
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 80_000,
            longitudinalMeters: 80_000
        )
        request.resultTypes = .pointOfInterest

        do {
            let response = try await MKLocalSearch(request: request).start()
            nearbyCourses = response.mapItems.map { item in
                let dist = location.distance(from: CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                ))
                return CourseResult(mapItem: item, distanceMeters: dist)
            }
            .sorted { $0.distanceMeters < $1.distanceMeters }
        } catch {
            nearbyCourses = []
        }
    }

    enum LocationError: LocalizedError {
        case denied
        var errorDescription: String? {
            "Location access is required to find nearby courses. Enable it in Settings > Privacy > Location Services."
        }
    }
}

extension CourseSearchService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        Task { @MainActor in
            self.locationContinuation?.resume(returning: loc)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationContinuation?.resume(throwing: error)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}

// MARK: - Result model

struct CourseResult: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
    let distanceMeters: Double

    var name: String { mapItem.name ?? "Unknown Course" }

    var distanceString: String {
        let miles = distanceMeters / 1609.344
        if miles < 10 { return String(format: "%.1f mi", miles) }
        return String(format: "%.0f mi", miles)
    }

    var address: String {
        let p = mapItem.placemark
        return [p.thoroughfare, p.locality, p.administrativeArea]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
