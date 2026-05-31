import SwiftUI
import PDFKit
import CoreLocation

@MainActor
class PDFExporter {
    static func generateEvidenceReport(ride: Ride) -> Data? {
        guard let points = ride.points, !points.isEmpty else { return nil }

        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { ctx in
            ctx.beginPage()

            let margin: CGFloat = 36
            let contentWidth: CGFloat = 540
            var yPos: CGFloat = margin

            let systemFont = UIFont.systemFont(ofSize: 10)
            let smallFont = UIFont.systemFont(ofSize: 9)
            let bold12 = UIFont.boldSystemFont(ofSize: 12)

            func drawText(_ text: String, font: UIFont, color: UIColor = .black, x: CGFloat = margin) {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                text.draw(at: CGPoint(x: x, y: yPos), withAttributes: attrs)
                yPos += font.lineHeight + 3
            }

            func drawTextCentered(_ text: String, font: UIFont, color: UIColor, _ rect: CGRect) {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let size = (text as NSString).size(withAttributes: attrs)
                text.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attrs)
            }

            func coloredLine(from: CGPoint, to: CGPoint, color: UIColor, width: CGFloat = 2) {
                let p = UIBezierPath()
                p.move(to: from)
                p.addLine(to: to)
                color.setStroke()
                p.lineWidth = width
                p.lineCapStyle = .round
                p.stroke()
            }

            // MARK: - Header
            let bgRect = CGRect(x: 0, y: 0, width: 612, height: 80)
            UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1).setFill()
            UIBezierPath(rect: bgRect).fill()

            "OPEN NINEBOT RIDE".draw(at: CGPoint(x: margin, y: 22), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor.white
            ])
            "EDR Evidence Report".draw(at: CGPoint(x: margin, y: 48), withAttributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.lightGray
            ])
            let reportID = "Report #\(Int.random(in: 10000...99999))"
            let ridSize = (reportID as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
            reportID.draw(at: CGPoint(x: 572 - ridSize.width, y: 22), withAttributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.lightGray
            ])
            let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
            let dsSize = (dateStr as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
            dateStr.draw(at: CGPoint(x: 572 - dsSize.width, y: 38), withAttributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.lightGray
            ])

            yPos = 100
            separator(at: yPos, ctx: ctx)

            yPos += 16

            // MARK: - Ride Info
            drawText("RIDE INFORMATION", font: UIFont.boldSystemFont(ofSize: 14), color: accentBlue)
            yPos += 2

            let df = DateFormatter()
            df.dateStyle = .long
            df.timeStyle = .short
            let rideDateStr = ride.endDate.map { df.string(from: $0) } ?? df.string(from: ride.startDate)
            let duration: TimeInterval = ride.endDate?.timeIntervalSince(ride.startDate) ?? 0
            let hours = Int(duration) / 3600; let mins = (Int(duration) % 3600) / 60; let secs = Int(duration) % 60
            let durStr = "\(hours)h \(mins)m \(secs)s"

            for (label, value) in [("Date", rideDateStr), ("Duration", durStr), ("Scooter", ride.scooterName ?? "Unknown"), ("Points", "\(points.count)")] {
                drawText(label, font: UIFont.boldSystemFont(ofSize: 10), color: .darkGray)
                drawText(value, font: systemFont, color: .black, x: margin + 120)
                yPos -= 3
            }
            yPos += 12

            // MARK: - Performance Summary
            let summaryBoxTop = yPos
            let boxH: CGFloat = 130
            roundedBox(y: yPos, w: contentWidth, h: boxH)
            yPos += 10

            drawText("PERFORMANCE SUMMARY", font: bold12, color: accentBlue, x: margin + 12)
            yPos += 4

            let halfW = contentWidth / 2 - 18
            let stats: [(String, String, String)] = [
                ("\(String(format: "%.1f", ride.maxSpeed)) km/h", "Top Speed", ""),
                ("\(String(format: "%.1f", ride.averageSpeed)) km/h", "Avg Speed", ""),
                (ride.distance >= 1000 ? "\(String(format: "%.2f", ride.distance / 1000)) km" : "\(String(format: "%.0f", ride.distance)) m", "Distance", ""),
                ("\(String(format: "%.1f", ride.maxAcceleration)) m/s²", "Max Accel", ""),
                ("\(String(format: "%.1f", ride.minSpeed == .greatestFiniteMagnitude ? 0 : ride.minSpeed)) km/h", "Min Speed", ""),
                ("\(String(format: "%.1f", ride.maxDeceleration)) m/s²", "Max Decel", ""),
            ]
            for (i, stat) in stats.enumerated() {
                let sx = margin + 12 + CGFloat(i % 2) * halfW
                let sy = yPos + CGFloat(i / 2) * 32
                (stat.0 as NSString).draw(at: CGPoint(x: sx, y: sy), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor.black])
                (stat.1 as NSString).draw(at: CGPoint(x: sx, y: sy + 20), withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.gray])
            }

            yPos = summaryBoxTop + boxH + 12

            // MARK: - Narrative
            ctx.beginPage()
            yPos = margin

            let narrBoxH: CGFloat = 90
            let narrBox = UIBezierPath(roundedRect: CGRect(x: margin, y: yPos, width: contentWidth, height: narrBoxH), cornerRadius: 6)
            UIColor(red: 0.97, green: 0.98, blue: 1.0, alpha: 1).setFill()
            narrBox.fill()
            UIColor(red: 0.75, green: 0.82, blue: 0.95, alpha: 1).setStroke()
            narrBox.lineWidth = 0.5
            narrBox.stroke()

            drawText("RIDE NARRATIVE", font: bold12, color: accentBlue, x: margin + 12)
            yPos += 2

            let narrative = generateNarrative(ride: ride, points: points, duration: duration)
            let textRect = CGRect(x: margin + 12, y: yPos, width: contentWidth - 24, height: narrBoxH - 40)
            (narrative as NSString).draw(in: textRect, withAttributes: [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: UIColor.darkGray
            ])
            yPos += narrBoxH - 30

            separator(at: yPos, ctx: ctx)
            yPos += 12

            // MARK: - Route Map
            ctx.beginPage()
            yPos = margin

            drawText("ROUTE MAP", font: UIFont.boldSystemFont(ofSize: 14), color: accentBlue)
            yPos += 8

            let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }
            let mapBoxY = yPos
            let mapBoxH: CGFloat = 200
            let mapBoxRect = CGRect(x: margin, y: mapBoxY, width: contentWidth, height: mapBoxH)

            let mb = UIBezierPath(roundedRect: mapBoxRect, cornerRadius: 6)
            UIColor(white: 0.97, alpha: 1).setFill()
            mb.fill()
            UIColor(white: 0.85, alpha: 1).setStroke()
            mb.lineWidth = 0.5
            mb.stroke()

            // Draw track on map
            if sortedPoints.count >= 2 {
                let lats = sortedPoints.map { $0.latitude }
                let lons = sortedPoints.map { $0.longitude }
                let minLat = lats.min()!, maxLat = lats.max()!
                let minLon = lons.min()!, maxLon = lons.max()!

                let padding: CGFloat = 20
                let drawW = contentWidth - padding * 2
                let drawH = mapBoxH - padding * 2
                let drawRect = CGRect(x: margin + padding, y: mapBoxY + padding, width: drawW, height: drawH)

                // Use uniform scale (Mercator-like)
                let latRange = maxLat - minLat
                let lonRange = maxLon - minLon
                let scale: CGFloat
                if latRange == 0 && lonRange == 0 {
                    scale = 1
                } else {
                    scale = min(drawW / CGFloat(lonRange == 0 ? 0.001 : lonRange),
                                drawH / CGFloat(latRange == 0 ? 0.001 : latRange)) * 0.85
                }

                let centerLat = (minLat + maxLat) / 2
                let centerLon = (minLon + maxLon) / 2
                let cx = drawRect.midX
                let cy = drawRect.midY

                for i in 0..<(sortedPoints.count - 1) {
                    let p1 = sortedPoints[i]
                    let p2 = sortedPoints[i + 1]
                    let avgSpeed = (p1.speed + p2.speed) / 2

                    let x1 = cx + CGFloat(p1.longitude - centerLon) * scale
                    let y1 = cy - CGFloat(p1.latitude - centerLat) * scale
                    let x2 = cx + CGFloat(p2.longitude - centerLon) * scale
                    let y2 = cy - CGFloat(p2.latitude - centerLat) * scale

                    coloredLine(from: CGPoint(x: x1, y: y1), to: CGPoint(x: x2, y: y2), color: UIColor(speedColor(avgSpeed)), width: 3)
                }

                // Start marker (green circle)
                let sx = cx + CGFloat(sortedPoints[0].longitude - centerLon) * scale
                let sy = cy - CGFloat(sortedPoints[0].latitude - centerLat) * scale
                UIColor.green.setFill()
                UIBezierPath(ovalIn: CGRect(x: sx - 4, y: sy - 4, width: 8, height: 8)).fill()
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: sx - 1.5, y: sy - 1.5, width: 3, height: 3)).fill()

                // End marker (red circle)
                let last = sortedPoints.last!
                let ex = cx + CGFloat(last.longitude - centerLon) * scale
                let ey = cy - CGFloat(last.latitude - centerLat) * scale
                UIColor.red.setFill()
                UIBezierPath(ovalIn: CGRect(x: ex - 4, y: ey - 4, width: 8, height: 8)).fill()
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: ex - 1.5, y: ey - 1.5, width: 3, height: 3)).fill()

                // Labels
                "S".draw(at: CGPoint(x: sx + 6, y: sy - 6), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: UIColor.green])
                "E".draw(at: CGPoint(x: ex + 6, y: ey - 6), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: UIColor.red])
            }

            // Legend
            let legY = mapBoxY + mapBoxH + 8
            for (i, (label, color)) in [("<8 km/h", UIColor.green), ("8–16", UIColor.yellow), ("16–24", UIColor.orange), (">24", UIColor.red)].enumerated() {
                let lx = margin + CGFloat(i) * 90
                coloredLine(from: CGPoint(x: lx, y: legY + 6), to: CGPoint(x: lx + 20, y: legY + 6), color: color, width: 3)
                (label as NSString).draw(at: CGPoint(x: lx + 24, y: legY + 1), withAttributes: [.font: smallFont, .foregroundColor: UIColor.darkGray])
            }

            yPos = legY + 20
            separator(at: yPos, ctx: ctx)
            yPos += 12

            // MARK: - Event Log
            if let events = ride.events?.sorted(by: { $0.timestamp < $1.timestamp }), !events.isEmpty {
                ctx.beginPage()
                yPos = margin

                drawText("EVENT LOG", font: UIFont.boldSystemFont(ofSize: 14), color: accentRed)
                yPos += 4

                for event in events {
                    if yPos > 730 {
                        ctx.beginPage()
                        yPos = margin
                    }
                    let ef = DateFormatter()
                    ef.timeStyle = .medium
                    let timeStr = ef.string(from: event.timestamp)

                    let eBox = UIBezierPath(roundedRect: CGRect(x: margin, y: yPos, width: contentWidth, height: 26), cornerRadius: 4)
                    UIColor(red: 1, green: 0.95, blue: 0.95, alpha: 1).setFill()
                    eBox.fill()
                    UIColor(red: 1, green: 0.8, blue: 0.8, alpha: 1).setStroke()
                    eBox.lineWidth = 0.5
                    eBox.stroke()

                    "[\(timeStr)]".draw(at: CGPoint(x: margin + 8, y: yPos + 5), withAttributes: [.font: smallFont, .foregroundColor: UIColor.darkGray])
                    "\(event.eventType.uppercased())".draw(at: CGPoint(x: margin + 110, y: yPos + 5), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor.red])
                    "\(event.eventDescription)".draw(at: CGPoint(x: margin + 200, y: yPos + 5), withAttributes: [.font: smallFont, .foregroundColor: UIColor.darkGray])
                    "@ \(String(format: "%.1f", event.speed)) km/h".draw(at: CGPoint(x: 520, y: yPos + 5), withAttributes: [.font: smallFont, .foregroundColor: UIColor.gray])
                    yPos += 31
                }
                yPos += 8

                separator(at: yPos, ctx: ctx)
                yPos += 12
            }

            // MARK: - Data Table
            ctx.beginPage()
            yPos = margin

            drawText("FULL DATA RECORD", font: UIFont.boldSystemFont(ofSize: 14), color: accentBlue)
            yPos += 6

            let dateF = DateFormatter()
            dateF.timeStyle = .medium

            let columns = ["Time", "Speed", "Accel", "Brake", "Mode", "Bttery", "Event"]
            let colWidths: [CGFloat] = [80, 60, 60, 50, 60, 60, 80]

            // Header
            let hdrBox = UIBezierPath(roundedRect: CGRect(x: margin, y: yPos, width: contentWidth, height: 22), cornerRadius: 4)
            UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1).setFill()
            hdrBox.fill()

            var colX = margin + 8
            for (i, col) in columns.enumerated() {
                (col as NSString).draw(at: CGPoint(x: colX, y: yPos + 4), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: UIColor.white])
                colX += colWidths[i]
            }
            yPos += 24

            var rowIndex = 0
            for point in sortedPoints {
                if yPos > 740 {
                    ctx.beginPage()
                    yPos = margin
                    let hb = UIBezierPath(roundedRect: CGRect(x: margin, y: yPos, width: contentWidth, height: 22), cornerRadius: 4)
                    UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1).setFill()
                    hb.fill()
                    colX = margin + 8
                    for (i, col) in columns.enumerated() {
                        (col as NSString).draw(at: CGPoint(x: colX, y: yPos + 4), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: UIColor.white])
                        colX += colWidths[i]
                    }
                    yPos += 24
                    rowIndex = 0
                }

                if rowIndex % 2 == 1 {
                    let rb = UIBezierPath(rect: CGRect(x: margin, y: yPos - 1, width: contentWidth, height: 14))
                    UIColor(white: 0.97, alpha: 1).setFill()
                    rb.fill()
                }

                colX = margin + 8
                let timeStr = dateF.string(from: point.timestamp)
                let rowColor: UIColor = point.isEvent ? .red : (point.isBraking ? UIColor.systemOrange : .black)
                let vals = [timeStr,
                    String(format: "%.1f", point.speed),
                    String(format: "%.1f", point.acceleration),
                    point.isBraking ? "YES" : "—",
                    point.mode,
                    String(format: "%.0f%%", point.batteryLevel),
                    point.eventType ?? ""
                ]
                for (i, val) in vals.enumerated() {
                    (val as NSString).draw(at: CGPoint(x: colX, y: yPos), withAttributes: [.font: smallFont, .foregroundColor: rowColor])
                    colX += colWidths[i]
                }
                yPos += 14
                rowIndex += 1
            }

            // MARK: - Footer
            yPos = 756
            separator(at: yPos, ctx: ctx)
            yPos += 4
            drawText("Generated by Open Ninebot Ride — \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))", font: UIFont.italicSystemFont(ofSize: 8), color: .lightGray)
            drawText("This report is provided as-is and should be verified against the original data.", font: UIFont.italicSystemFont(ofSize: 8), color: .lightGray)
        }
    }

    // MARK: - Narrative Generator
    private static func generateNarrative(ride: Ride, points: [RidePoint], duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let mins = (Int(duration) % 3600) / 60
        let secs = Int(duration) % 60

        let distKm = ride.distance / 1000
        let topSpd = ride.maxSpeed
        let avgSpd = ride.averageSpeed
        let sorted = points.sorted { $0.timestamp < $1.timestamp }

        var parts: [String] = []

        // Opening
        if distKm >= 1.0 {
            parts.append("The ride covered \(String(format: "%.2f", distKm)) km over \(hours)h \(mins)m \(secs)s")
        } else {
            parts.append("The ride covered \(String(format: "%.0f", ride.distance)) meters over \(hours)h \(mins)m \(secs)s")
        }

        // Speed
        if topSpd > 25 {
            parts.append("reaching a top speed of \(String(format: "%.1f", topSpd)) km/h")
        } else if topSpd > 15 {
            parts.append("with a top speed of \(String(format: "%.1f", topSpd)) km/h")
        } else {
            parts.append("at a conservative pace")
        }

        if avgSpd > 20 {
            parts.append("and maintaining a brisk average of \(String(format: "%.1f", avgSpd)) km/h")
        } else if avgSpd > 10 {
            parts.append("averaging \(String(format: "%.1f", avgSpd)) km/h")
        }

        // Braking analysis
        let brakes = sorted.filter { $0.isBraking }.count
        let hardBrakes = ride.events?.filter { $0.eventType == "hard_brake" }.count ?? 0
        let accels = ride.events?.filter { $0.eventType == "rapid_accel" }.count ?? 0
        let modeChanges = ride.events?.filter { $0.eventType == "mode_change" }.count ?? 0

        if hardBrakes > 0 {
            parts.append("\(hardBrakes) hard braking event(s) were recorded")
        }
        if brakes > 0 && hardBrakes == 0 {
            parts.append("the ride included \(brakes) braking instance(s)")
        }
        if accels > 0 {
            parts.append("along with \(accels) rapid acceleration(s)")
        }
        if modeChanges > 0 {
            parts.append("the rider switched drive mode \(modeChanges) time(s)")
        }

        // Top speed vs avg speed delta
        let delta = topSpd - avgSpd
        if delta > 20 {
            parts.append("showing significant speed variation throughout the journey")
        } else if delta < 5 && topSpd > 15 {
            parts.append("maintaining remarkably consistent speed")
        }

        // Distance
        if ride.distance > 5000 {
            parts.append("covering a substantial distance of \(String(format: "%.0f", ride.distance)) meters")
        } else if ride.distance < 200 {
            parts.append("a very short trip")
        }

        // Acceleration context
        if ride.maxAcceleration > 5 {
            parts.append("with aggressive acceleration detected (peak \(String(format: "%.1f", ride.maxAcceleration)) m/s²)")
        }
        if ride.maxDeceleration < -5 {
            parts.append("and abrupt deceleration events (peak \(String(format: "%.1f", ride.maxDeceleration)) m/s²)")
        }

        // Lights
        let lightsOnCount = sorted.filter { $0.lightsOn }.count
        let lightsRatio = Double(lightsOnCount) / Double(max(sorted.count, 1))
        if lightsRatio > 0.8 {
            parts.append("lights were active for most of the ride")
        } else if lightsRatio < 0.2 {
            parts.append("lights were off for most of the ride")
        }

        // Duration
        if duration > 3600 {
            parts.append("a ride lasting over an hour")
        } else if duration < 120 {
            parts.append("a brief ride under two minutes")
        }

        let fullText = parts.joined(separator: "; ") + "."
        return fullText.prefix(1).uppercased() + fullText.dropFirst()
    }

    // MARK: - Helpers
    private static let accentBlue = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)
    private static let accentRed = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)

    private static func separator(at y: CGFloat, ctx: UIGraphicsPDFRendererContext) {
        let sep = UIBezierPath()
        sep.move(to: CGPoint(x: 36, y: y))
        sep.addLine(to: CGPoint(x: 576, y: y))
        UIColor(white: 0.85, alpha: 1).setStroke()
        sep.lineWidth = 0.5
        sep.stroke()
    }

    private static func roundedBox(y: CGFloat, w: CGFloat, h: CGFloat) {
        let margin: CGFloat = 36
        let box = UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: w, height: h), cornerRadius: 6)
        UIColor(white: 0.95, alpha: 1).setFill()
        box.fill()
        UIColor(white: 0.85, alpha: 1).setStroke()
        box.lineWidth = 0.5
        box.stroke()
    }

    private static func speedColor(_ speed: Double) -> Color {
        if speed < 8 { return .green }
        if speed < 16 { return .yellow }
        if speed < 24 { return .orange }
        return .red
    }
}
