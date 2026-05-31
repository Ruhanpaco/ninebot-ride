# Ninebot Ride

**Open-source iOS app** that connects to Segway-Ninebot electric scooters over Bluetooth Low Energy, reads live telemetry, records rides with GPS tracking, and generates EDR (Event Data Recorder) reports.

Built for riders, tinkerers, and anyone who wants full access to their scooter's data without proprietary apps.

---

## Features

- **BLE Scan & Connect** — discover nearby Ninebot scooters, connect, and authenticate using the official Encryption2 protocol
- **Live Dashboard** — real-time speed gauge, battery level, voltage, current, acceleration, brake detection, turn signals, and riding mode (Eco/Drive/Sport)
- **Ride Recording** — GPS-tracked rides with continuous speed, mode, lights, battery, voltage, and current logging
- **Event Detection** — automatically detects hard braking, rapid acceleration, and mode changes during a ride
- **Ride History** — browse past rides with distance, max speed, average speed, acceleration metrics, and event count
- **Export & EDR Reports** — export all ride data as JSON, or generate a styled PDF Event Data Recorder report
- **Live Activity** — keeps your speed, mode, and battery visible on the iOS Dynamic Island and Lock Screen during a ride
- **Map View** — see your recorded route overlaid with speed-colored segments and event markers
- **Settings & Data Management** — view paired scooters, manage ride data, export or delete

## Scooter Support

| Series | Models | Protocol |
|--------|--------|----------|
| E | E22, E25, E45, **E2**, **E2 Pro** | Encryption2 (Gen3) |
| F | F20, F25, F30, F40, F65 | Encryption2 |
| F2 | F2, F2 Plus, F2 Pro | Encryption2 (Gen3) |
| Max | G30, G30LP | Encryption2 |
| Max G2 | G2 | Encryption2 (Gen3) |
| GT | GT1, GT2 | Encryption2 |
| P | P65, P100S | Encryption2 (Gen3) |
| ES | ES1, ES2, ES4 | Legacy (Gen2) |
| Other | SNSC, ZING, Air T, D Series | Mixed |

## How It Works

### 1. Bluetooth Connection

The app scans for Ninebot devices advertising the Ninebot Custom BLE service (`6e400001-0000-0000-006e-696e65626f74`). Once discovered, it connects and finds the UART-style write (`0002`) and notify (`0004`) characteristics.

### 2. Encrypted Authentication (Encryption2)

Ninebot Gen3 scooters (E2 Pro, F2, Max G2, GT, P-series) use a three-phase encrypted handshake:

1. **PRE_COMM (0x5B)** — send an initial encrypted frame to request the scooter's auth parameter and serial number
2. **SET_PWD (0x5C)** — generate a time-based session password, encrypt it, and send it to the scooter
3. **AUTH (0x5D)** — prove identity with the password; on success the scooter opens its register interface

The crypto layer uses:
- **AES-128-ECB** for frame encryption/decryption
- **SHA-1** for key derivation from the scooter's BLE name
- **CBC-MAC** for message authentication in SN mode
- **Complement-of-sum checksum** for non-SN integrity

### 3. Live Data Polling

After authentication, the app polls controller registers at 1 Hz to read:
- Speed (km/h)
- Battery level (%)
- Voltage (V) and current (A)
- Acceleration / deceleration
- Brake state
- Turn signal state
- Riding mode
- Lights on/off
- Odometer (km)

### 4. Ride Recording

When recording, the app stores a `Ride` object in SwiftData with:
- Start/end timestamps and duration
- Route as a series of `RidePoint` records (timestamp, GPS coordinate, speed, mode, lights, battery, voltage, current, acceleration, brake state)
- Detected events as `EventRecord` entries (hard brake, rapid acceleration, mode change)
- Derived stats: max/min/average speed, total distance, max acceleration/deceleration

### 5. EDR Reports

The PDF exporter generates a forensic-style Event Data Recorder report containing:
- Ride summary (date, duration, distance, speed stats)
- Speed graph
- Event timeline
- All raw data points
- Event Data Markers

## Project Structure

```
Services/
├── NinebotCrypto.swift      # AES-128-ECB, SHA-1 key derivation, CBC-MAC, password gen, handshake state machine
├── NinebotProtocol.swift     # Frame builder/parser, BLE UUIDs, BoardID enum, device model detection
├── ScooterManager.swift      # Bluetooth lifecycle, auth flow, register polling, ride recording
├── BLEScanner.swift          # Central manager, scanning, connection with continuation pattern
├── LiveActivityManager.swift # iOS Live Activity / Dynamic Island updates
Models/
├── Scooter.swift             # SwiftData model for paired scooter
├── Ride.swift                # SwiftData model for a ride
├── RidePoint.swift           # SwiftData model for individual data point
├── EventRecord.swift         # SwiftData model for detected events
Views/
├── DashboardView.swift       # Speed gauge, stats, ride controls
├── ConnectView.swift         # BLE scan, connect, connection status
├── MapPage.swift             # Map with route overlay, recording controls, live HUD
├── RideHistoryView.swift     # List of past rides
├── RideDetailView.swift      # Detailed ride stats + map replay
├── SettingsView.swift        # Scooters, data management, about
├── BlackBoxView.swift        # EDR report viewer
├── ScooterPickerView.swift   # BLE device selection sheet
├── MapWithRouteView.swift    # MapKit wrapper with route + event annotations
├── CircularGauge.swift       # Custom speed gauge component
Utilities/
├── PDFExporter.swift         # EDR report PDF generation
├── EventDetector.swift       # Real-time event detection logic
├── SpeedGradient.swift       # Speed color mapping for map overlays
├── DashboardStyle.swift      # Shared styling helpers
```

## Building

Requires **Xcode 15+** and **iOS 17+**.

```bash
open "Open Ninebot Ride.xcodeproj"
```

Select your team in Signing & Capabilities, then build and run on a real iOS device.

> BLE and Core Location require real hardware — the iOS simulator does not support Bluetooth or GPS.

## Protocol Reference

This project follows the [Segway-Ninebot BLE Protocol](https://nootnooot.codeberg.page/segway-ninebot-ble/) documentation, which has been reverse-engineered to enable third-party interoperability under EU Directive 2009/24/EC.

Related projects and references:
- [segway-ninebot-ble](https://github.com/EGGreat/segway-ninebot-ble) — JavaScript implementation for Web BLE
- [Esco-NBIOT](https://github.com/EGGreat/Esco-NBIOT) — Flutter app with Ninebot BLE support
- [ninebot-ble](https://github.com/elordin/ninebot-ble) — Python library for Ninebot protocol

## ⚠️ Looking for Contributors

I need help from the community to get this working reliably across different scooter models and firmware versions. Specifically:

- **BLE / CoreBluetooth expertise** — debug why the scooter's auth response notifications aren't being received (iOS BLE notification subscription timing)
- **Crypto verification** — confirm the key derivation and encryption match what `libnbcrypto.so` on the scooter expects
- **Testing on real hardware** — I only have an E2 Pro. If you have another model (F-series, Max, GT, etc.) please test and report what works
- **Ninebot protocol knowledge** — if you've reverse-engineered the handshake or know about firmware-specific quirks (e.g., different `ecb_input` constants, counter behavior)
- **iOS development** — polish the UI, add more features, fix edge cases

If you can help, please open an issue or pull request. Every bit helps.

## License

Copyright (C) 2024-2026  Open Ninebot Ride Contributors

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
