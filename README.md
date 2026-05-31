# Ninebot Ride

An open-source iOS app for connecting to Segway-Ninebot electric scooters over Bluetooth Low Energy.

Reads live telemetry — speed, battery, voltage, current, ride recording — from the scooter's BLE interface using the **Encryption2 protocol**.

> **Status: work in progress.** The BLE connection and encryption handshake are implemented, but authentication against real hardware is still being debugged. Contributions welcome.

---

## Features

- BLE scan + connect to Ninebot scooters (E2 Pro, F-series, Max G2, ES, GT, and more)
- AES-128-ECB + SHA-1 key derivation per Encryption2 spec
- 3-phase auth handshake: PRE_COMM → SET_PWD → AUTH
- Live register polling (speed, battery, voltage, current)
- Ride recording with GPS tracking
- iOS Live Activity support


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

## Project Structure

- `Services/NinebotCrypto.swift` — AES-128-ECB encryption, SHA-1 key derivation, CBC-MAC, password generation, three-phase handshake state machine
- `Services/NinebotProtocol.swift` — Frame builder/parser, BLE service/characteristic UUIDs, BoardID enum, device model detection
- `Services/ScooterManager.swift` — Bluetooth lifecycle, auth flow, register polling, ride recording
- `Services/BLEScanner.swift` — Central manager, scanning, connection with continuation pattern

## Building

Requires Xcode 15+ and iOS 17+.

```bash
open "Open Ninebot Ride.xcodeproj"
```

Select your team in Signing & Capabilities, then build and run on a real iOS device.

## How It Works

1. **BLE connect** — scan for Ninebot devices, connect, discover UART service
2. **Auth handshake** — three encrypted messages establish a session key:
   - `PRE_COMM (0x5B)` → get auth parameter and serial number
   - `SET_PWD (0x5C)` → send a time-based session password
   - `AUTH (0x5D)` → prove identity with the password
3. **Register polling** — read real-time data from the controller (speed, battery, etc.) at 1 Hz
4. **Ride recording** — log GPS + scooter data to a local SwiftData store

All communication uses the Ninebot Custom BLE service (`6e400001-0000-0000-006e-696e65626f74`) with write characteristic `0002` and notify characteristic `0004`.

## Protocol Reference

This project follows the [Segway-Ninebot BLE Protocol](https://nootnooot.codeberg.page/segway-ninebot-ble/) documentation — reverse-engineered for interoperability under EU Directive 2009/24/EC.

## ⚠️ Looking for Contributors

I need help from the community to get this working reliably across different scooter models and firmware versions. Specifically:

- **BLE / CoreBluetooth expertise** — debug why the scooter's auth response notifications aren't being received (iOS BLE notification subscription timing)
- **Crypto verification** — confirm the key derivation and encryption match what `libnbcrypto.so` on the scooter expects
- **Testing on real hardware** — I only have an E2 Pro. If you have another model (F-series, Max, GT, etc.) please test and report what works
- **Ninebot protocol knowledge** — if you've reverse-engineered the handshake or know about firmware-specific quirks (e.g., different `ecb_input` constants, counter behavior)
- **iOS development** — polish the UI, add more features, fix edge cases

If you can help, please open an issue or pull request. Every bit helps.

## License

MIT
