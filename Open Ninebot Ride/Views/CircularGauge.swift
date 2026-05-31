import SwiftUI

struct CircularGauge: View {
    let speed: Double
    let maxSpeed: Double

    private var speedRatio: Double { maxSpeed > 0 ? min(speed / maxSpeed, 1.0) : 0 }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                Circle()
                    .stroke(lineWidth: 2)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: size, height: size)

                Circle()
                    .trim(from: 0, to: speedRatio * 0.75)
                    .stroke(speedColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size - 4, height: size - 4)
                    .animation(.snappy(duration: 0.3), value: speed)

                VStack(spacing: 0) {
                    Text("\(Int(speed))")
                        .font(.system(size: size * 0.28, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("km/h")
                        .font(.system(size: size * 0.04, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(2)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var speedColor: Color {
        if speed < 10 { return Color(red: 0.2, green: 0.8, blue: 0.3) }
        if speed < 20 { return Color(red: 1.0, green: 0.8, blue: 0.0) }
        return Color(red: 1.0, green: 0.2, blue: 0.2)
    }
}
