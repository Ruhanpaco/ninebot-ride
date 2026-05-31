import SwiftUI
import MapKit

struct MapWithRouteView: UIViewRepresentable {
    var routePoints: [RidePoint]
    var currentSpeed: Double
    var currentMode: String
    var lightsOn: Bool
    var userLocation: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.mapType = .mutedStandard
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = false
        map.showsScale = false
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        if routePoints.isEmpty, let loc = userLocation, !context.coordinator.didInitialZoom {
            let region = MKCoordinateRegion(
                center: loc,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
            map.setRegion(region, animated: false)
            context.coordinator.didInitialZoom = true
            return
        }

        if routePoints.count <= context.coordinator.lastPointCount { return }

        let sorted = routePoints.sorted { $0.timestamp < $1.timestamp }

        if sorted.count == 1 {
            let circle = MKCircle(center: sorted[0].coordinate, radius: 3)
            map.addOverlay(circle)
            context.coordinator.lastPointCount = 1
            return
        }

        for i in context.coordinator.lastPointCount..<(sorted.count - 1) {
            let p1 = sorted[i]
            let p2 = sorted[i + 1]
            let avgSpeed = (p1.speed + p2.speed) / 2
            var coords = [
                CLLocationCoordinate2D(latitude: p1.latitude, longitude: p1.longitude),
                CLLocationCoordinate2D(latitude: p2.latitude, longitude: p2.longitude)
            ]
            let polyline = SpeedPolyline(coordinates: &coords, count: 2)
            polyline.speed = avgSpeed
            map.addOverlay(polyline)
        }

        context.coordinator.lastPointCount = sorted.count - 1
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var didInitialZoom = false
        var lastPointCount = 0

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? SpeedPolyline {
                let r = MKPolylineRenderer(polyline: polyline)
                r.strokeColor = UIColor(speedColor(polyline.speed))
                r.lineWidth = 4
                r.lineCap = .round
                r.lineJoin = .round
                return r
            }
            if let circle = overlay as? MKCircle {
                let r = MKCircleRenderer(circle: circle)
                r.fillColor = UIColor(speedColor(0))
                r.alpha = 0.6
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        private func speedColor(_ speed: Double) -> Color {
            if speed < 8 { return .green }
            if speed < 16 { return .yellow }
            if speed < 24 { return .orange }
            return .red
        }
    }
}

class SpeedPolyline: MKPolyline {
    var speed: Double = 0
}
