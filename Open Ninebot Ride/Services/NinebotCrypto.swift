import Foundation
import CommonCrypto

// MARK: - FW_DATA constant (Gen2 non-SN ECB input)
private let FW_DATA: [UInt8] = [
    0x97, 0xCF, 0xB8, 0x02, 0x84, 0x41, 0x43, 0xDE,
    0x56, 0x00, 0x2B, 0x3B, 0x34, 0x78, 0x0A, 0x5D
]

// MARK: - AES-128-ECB single block encrypt
private func aesEcbEncrypt(_ key: [UInt8], _ block: [UInt8]) -> [UInt8] {
    var out = [UInt8](repeating: 0, count: 16)
    var outLen = 0
    CCCrypt(
        CCOperation(kCCEncrypt),
        CCAlgorithm(kCCAlgorithmAES),
        CCOptions(kCCOptionECBMode),
        key, kCCKeySizeAES128,
        nil,
        block, block.count,
        &out, out.count,
        &outLen
    )
    return Array(out.prefix(outLen))
}

// MARK: - Key derivation: SHA-1(key1_pad16 + key2_pad16)[0:16]
private func deriveKey(_ key1: [UInt8], _ key2: [UInt8]?) -> [UInt8] {
    let k1 = (key1 + [UInt8](repeating: 0, count: 16)).prefix(16)
    let k2 = (key2.map { $0 } ?? [UInt8](repeating: 0, count: 16)).prefix(16)
    var data = Array(k1) + Array(k2)
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    data.withUnsafeBytes { ptr in
        _ = CC_SHA1(ptr.baseAddress, CC_LONG(data.count), &digest)
    }
    return Array(digest.prefix(16))
}

// MARK: - Nonce/block construction
private let MAGIC: [UInt8] = [0x5A, 0xA5]

private func buildNonce(_ counter: Int, _ auth: [UInt8]) -> [UInt8] {
    var n = [UInt8](repeating: 0, count: 13)
    n[0] = UInt8((counter >> 24) & 0xFF)
    n[1] = UInt8((counter >> 16) & 0xFF)
    n[2] = UInt8((counter >> 8) & 0xFF)
    n[3] = UInt8(counter & 0xFF)
    for i in 0..<8 { n[4 + i] = auth[i] }
    n[12] = 0
    return n
}

private func aBlock(_ n: [UInt8], _ i: Int) -> [UInt8] {
    [0x01] + n + [0x00, UInt8(truncatingIfNeeded: i & 0xFF)]
}

private func b0Block(_ n: [UInt8], _ payloadLen: Int) -> [UInt8] {
    [0x59] + n + [0x00, UInt8(truncatingIfNeeded: payloadLen & 0xFF)]
}

// MARK: - CBC-MAC
private func cbcMac(_ key: [UInt8], _ pt: [UInt8], _ nonce: [UInt8]) -> [UInt8] {
    let payloadLen = pt.count - 3
    var x = aesEcbEncrypt(key, b0Block(nonce, payloadLen))
    let aad = pt[0..<3] + [UInt8](repeating: 0, count: 13)
    x = aesEcbEncrypt(key, xor16(x, Array(aad)))
    var offset = 3
    while offset < pt.count {
        let end = min(offset + 16, pt.count)
        var chunk = Array(pt[offset..<end])
        chunk += [UInt8](repeating: 0, count: 16 - chunk.count)
        x = aesEcbEncrypt(key, xor16(x, chunk))
        offset += 16
    }
    return Array(x.prefix(4))
}

// MARK: - CTR XOR
private func ctrXor(_ key: [UInt8], _ data: [UInt8], _ nonce: [UInt8], start: Int = 1) -> [UInt8] {
    var out = [UInt8]()
    var bi = start
    var off = 0
    while off < data.count {
        let ks = aesEcbEncrypt(key, aBlock(nonce, bi))
        let len = min(16, data.count - off)
        for j in 0..<len { out.append(data[off + j] ^ ks[j]) }
        off += 16; bi += 1
    }
    return out
}

private func xor16(_ a: [UInt8], _ b: [UInt8]) -> [UInt8] {
    zip(a, b).map(^)
}

// MARK: - Java LCG (java.util.Random)
private let JMASK: Int64 = (1 << 48) - 1
private let JMULT: Int64 = 0x5DEECE66D
private let JADD: Int64 = 0xB

private struct JavaRandom {
    private var seed: Int64
    init(seed: Int64) {
        self.seed = (seed ^ JMULT) & JMASK
    }
    private mutating func next(_ bits: Int) -> Int32 {
        seed = (seed * JMULT + JADD) & JMASK
        return Int32(truncatingIfNeeded: seed >> (48 - bits))
    }
    mutating func nextBytes(_ n: Int) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: n)
        var i = 0
        while i < n {
            let r = next(32)
            for j in 0..<min(4, n - i) {
                out[i] = UInt8(truncatingIfNeeded: (r >> (8 * j)) & 0xFF)
                i += 1
            }
        }
        return out
    }
}

// MARK: - Password generation
private func generatePassword(auth: [UInt8]) -> [UInt8] {
    let timeMs = Int64(Date().timeIntervalSince1970 * 1000)
    var j: Int64 = 0
    for i in 0..<auth.count {
        let sb = Int64(auth[i] < 128 ? Int(auth[i]) : Int(auth[i]) - 256)
        let val = Int32(truncatingIfNeeded: sb << ((i % 8) * 8 & 31))
        j = Int64(truncatingIfNeeded: j + Int64(val))
    }
    let seed = timeMs + j
    var rng = JavaRandom(seed: seed)
    var rb = rng.nextBytes(16)
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    rb.withUnsafeBytes { ptr in
        _ = CC_SHA256(ptr.baseAddress, CC_LONG(rb.count), &digest)
    }
    return Array(digest.prefix(16))
}

// MARK: - Stored password management
private var storedPasswords: [String: [UInt8]] = [:]

func storePassword(mac: String, password: [UInt8]) {
    storedPasswords[mac] = password
}

func retrievePassword(mac: String) -> [UInt8]? {
    storedPasswords[mac]
}

func clearPassword(mac: String) {
    storedPasswords.removeValue(forKey: mac)
}

// MARK: - NbCrypto (stateful encryption context)
class NbCrypto {
    var key1: [UInt8]?
    var key2: [UInt8]?
    var auth: [UInt8] = [UInt8](repeating: 0, count: 16)
    var counter: Int = 0
    let ecbInput: [UInt8]

    init(ecbInput: [UInt8]? = nil) {
        self.ecbInput = ecbInput ?? [UInt8](repeating: 0, count: 16)
    }

    func setKey(_ k1: [UInt8], _ k2: [UInt8]?) {
        key1 = k1; key2 = k2
    }
    func setAuth(_ a: [UInt8]) { auth = Array(a.prefix(16)) }
    func startSN() { counter = 1 }
    func resetSN() { counter = 0 }

    private var aesKey: [UInt8] { deriveKey(key1 ?? [], key2) }

    // MARK: - Encrypt
    func encrypt(_ pt: [UInt8]) -> [UInt8] {
        let key = aesKey
        let hdr = Array(pt.prefix(3))
        return counter > 0 ? _encryptSN(key, pt, hdr) : _encryptNonSN(key, pt, hdr)
    }

    private func _encryptSN(_ key: [UInt8], _ pt: [UInt8], _ hdr: [UInt8]) -> [UInt8] {
        counter += 1
        let nonce = buildNonce(counter, auth)
        let rawTag = cbcMac(key, pt, nonce)
        let ct = ctrXor(key, Array(pt.dropFirst(3)), nonce, start: 1)
        let a0ks = aesEcbEncrypt(key, aBlock(nonce, 0))
        let encTag = xor16(rawTag, Array(a0ks.prefix(4)))
        let ctrTail: [UInt8] = [UInt8((counter >> 8) & 0xFF), UInt8(counter & 0xFF)]
        return hdr + ct + encTag + ctrTail
    }

    private func _encryptNonSN(_ key: [UInt8], _ pt: [UInt8], _ hdr: [UInt8]) -> [UInt8] {
        let pl = Array(pt.dropFirst(3))
        let csum = (~pl.reduce(0) { $0 + Int($1) }) & 0xFFFF
        let ks = aesEcbEncrypt(key, ecbInput)
        var out = [UInt8]()
        var off = 0
        while off < pl.count {
            let len = min(16, pl.count - off)
            for j in 0..<len { out.append(pl[off + j] ^ ks[j]) }
            off += 16
        }
        let tail: [UInt8] = [0, 0, UInt8(csum & 0xFF), UInt8((csum >> 8) & 0xFF), 0, 0]
        return hdr + out + tail
    }

    // MARK: - Decrypt
    func decrypt(_ cf: [UInt8]) -> (pt: [UInt8], rc: Int) {
        let key = aesKey
        let hdr = Array(cf.prefix(3))
        let tail = Array(cf.suffix(6))
        let body = Array(cf[3..<cf.count-6])
        let rc = (Int(tail[4]) << 8) | Int(tail[5])
        return rc > 0 ? _decryptSN(key, hdr, body, tail, rc) : _decryptNonSN(key, hdr, body, tail)
    }

    private func _decryptSN(_ key: [UInt8], _ hdr: [UInt8], _ body: [UInt8], _ tail: [UInt8], _ rc: Int) -> ([UInt8], Int) {
        let nonce = buildNonce(rc, auth)
        let pl = ctrXor(key, body, nonce, start: 1)
        let pt = hdr + pl
        let encTag = Array(tail.prefix(4))
        let a0ks = aesEcbEncrypt(key, aBlock(nonce, 0))
        let recvTag = xor16(encTag, Array(a0ks.prefix(4)))
        let expTag = cbcMac(key, pt, nonce)
        guard recvTag == expTag else { return (pt, -2) }
        return (pt, 0)
    }

    private func _decryptNonSN(_ key: [UInt8], _ hdr: [UInt8], _ body: [UInt8], _ tail: [UInt8]) -> ([UInt8], Int) {
        let ks = aesEcbEncrypt(key, ecbInput)
        var out = [UInt8]()
        var off = 0
        while off < body.count {
            let len = min(16, body.count - off)
            for j in 0..<len { out.append(body[off + j] ^ ks[j]) }
            off += 16
        }
        let pt = hdr + out
        let pl = Array(pt.dropFirst(3))
        let ec = (~pl.reduce(0) { $0 + Int($1) }) & 0xFFFF
        let rc = Int(tail[2]) | (Int(tail[3]) << 8)
        guard ec == rc else { return (pt, -2) }
        return (pt, 0)
    }
}

// MARK: - NinebotHandshake (manages the full three-phase auth)
class NinebotHandshake {
    private let crypto: NbCrypto
    private let gen: ProtocolGen
    private let btName: String
    private let mac: String

    var authParam: [UInt8] = []
    var serialNumber: [UInt8] = []
    var password: [UInt8] = []

    init(gen: ProtocolGen, btName: String, mac: String) {
        self.gen = gen
        self.btName = btName
        self.mac = mac
        let ecb = gen == .gen2 ? FW_DATA : [UInt8](repeating: 0, count: 16)
        self.crypto = NbCrypto(ecbInput: ecb)
    }

    /// Build PRE_COMM request (cmd=0x5B, no payload)
    func buildPRE_COMM() -> [UInt8] {
        crypto.resetSN()
        crypto.setKey([UInt8](btName.utf8), nil)
        let frame = NinebotFrame.build(target: .ble, cmd: 0x5B, index: 0)
        return crypto.encrypt(frame)
    }

    /// Process PRE_COMM response → extract auth + serial
    func processPRE_COMM(response: [UInt8]) throws -> Bool {
        let (pt, rc) = crypto.decrypt(response)
        guard rc == 0, pt.count >= 7 else { throw NinebotError.authFailed("Invalid PRE_COMM response") }
        let dataLen = Int(pt[2])
        guard pt.count >= 7 + dataLen, dataLen >= 30 else { throw NinebotError.authFailed("PRE_COMM data too short") }
        authParam = Array(pt[7..<23])
        serialNumber = Array(pt[23..<7 + dataLen])
        password = generatePassword(auth: authParam)
        crypto.setAuth(authParam)
        crypto.startSN()
        return true
    }

    /// Build SET_PWD request (cmd=0x5C, payload = 16-byte password)
    func buildSET_PWD() -> [UInt8] {
        crypto.setKey([UInt8](btName.utf8), authParam)
        let frame = NinebotFrame.build(target: .ble, cmd: 0x5C, index: 0, data: password)
        return crypto.encrypt(frame)
    }

    /// Build AUTH request (cmd=0x5D, payload = 14-byte serial)
    func buildAUTH() -> [UInt8] {
        crypto.setKey(password, authParam)
        let frame = NinebotFrame.build(target: .ble, cmd: 0x5D, index: 0, data: Array(serialNumber.prefix(14)))
        return crypto.encrypt(frame)
    }

    /// Process SET_PWD or AUTH response — returns INDEX byte (status)
    func processResponse(_ response: [UInt8]) throws -> Int {
        let (pt, rc) = crypto.decrypt(response)
        guard rc == 0, pt.count >= 7 else { throw NinebotError.authFailed("Invalid response") }
        let dataLen = Int(pt[2])
        guard pt.count >= 7 + dataLen else { throw NinebotError.authFailed("Invalid response") }
        return Int(pt[6])
    }

    var cryptoRef: NbCrypto { crypto }
    var serialString: String {
        String(data: Data(serialNumber), encoding: .ascii) ?? ""
    }
}

enum NinebotError: Error, LocalizedError {
    case authFailed(String)
    case invalidResponse(String)
    case timeout
    var errorDescription: String? {
        switch self { case .authFailed(let s), .invalidResponse(let s): return s; case .timeout: return "Timeout" }
    }
}
