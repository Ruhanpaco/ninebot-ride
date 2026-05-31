import SwiftUI

enum SpeedGradient {
    static func color(for speed: Double, maxSpeed: Double = 30) -> Color {
        let ratio = maxSpeed > 0 ? min(speed / maxSpeed, 1.0) : 0
        if ratio < 0.33 {
            return .green
        } else if ratio < 0.66 {
            return .yellow
        } else {
            return .red
        }
    }

    static func uiColor(for speed: Double, maxSpeed: Double = 30) -> UIColor {
        let ratio = maxSpeed > 0 ? min(speed / maxSpeed, 1.0) : 0
        if ratio < 0.33 {
            return .green
        } else if ratio < 0.66 {
            return .yellow
        } else {
            return .red
        }
    }

    static func mapColor(for speed: Double, maxSpeed: Double = 30) -> UIColor {
        let ratio = maxSpeed > 0 ? min(speed / maxSpeed, 1.0) : 0
        let r: CGFloat = ratio
        let g: CGFloat = 1.0 - ratio
        let b: CGFloat = 0
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    static func rgba(for speed: Double, maxSpeed: Double = 30) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let ratio = maxSpeed > 0 ? min(speed / maxSpeed, 1.0) : 0
        return (r: ratio, g: 1.0 - ratio, b: 0, a: 1.0)
    }

    static var gradient: Gradient {
        Gradient(colors: [.green, .yellow, .orange, .red])
    }

    static var stops: [(CGFloat, Color)] {
        [(0, .green), (0.33, .yellow), (0.66, .orange), (1.0, .red)]
    }
}
