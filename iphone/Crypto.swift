import Foundation
import CryptoKit

enum Crypto {
    private static let master = SymmetricKey(data: SHA256.hash(data: Data(Config.token.utf8)))
    private static let lock = NSLock()
    private static var last: [UInt8: UInt64] = [:]
    private static let window: UInt64 = 1_000_000_000

    private static func derive(_ d: UInt8, _ n: UInt64) -> SymmetricKey {
        var salt = Data([d])
        withUnsafeBytes(of: n.bigEndian) { salt.append(contentsOf: $0) }
        return HKDF<SHA256>.deriveKey(inputKeyMaterial: master, salt: salt,
                                      info: Data("l360.v2".utf8), outputByteCount: 32)
    }

    static func seal(_ s: String, dir: UInt8 = 0) -> String? {
        lock.lock(); defer { lock.unlock() }
        let n = (last[dir] ?? 0) + 1
        last[dir] = n
        guard let d = s.data(using: .utf8),
              let b = try? AES.GCM.seal(d, using: derive(dir, n)),
              let c = b.combined else { return nil }
        var out = Data([dir])
        withUnsafeBytes(of: n.bigEndian) { out.append(contentsOf: $0) }
        out.append(c)
        return out.base64EncodedString()
    }

    static func open(_ b: String) -> String? {
        guard let raw = Data(base64Encoded: b), raw.count > 37 else { return nil }
        let dir = raw[0]
        guard dir <= 3 else { return nil }
        let n = raw.subdata(in: 1..<9).withUnsafeBytes { $0.loadUnaligned(as: UInt64.self).bigEndian }
        lock.lock()
        let seen = last[dir] ?? 0
        guard n > seen || seen - n > window else { lock.unlock(); return nil }
        last[dir] = n
        lock.unlock()
        guard let box = try? AES.GCM.SealedBox(combined: raw.dropFirst(9)),
              let p = try? AES.GCM.open(box, using: derive(dir, n)) else { return nil }
        return String(data: p, encoding: .utf8)
    }

    static func sealClip(_ d: Data, name: String) -> Data? {
        let k = HKDF<SHA256>.deriveKey(inputKeyMaterial: master, salt: Data(("clip:" + name).utf8),
                                       info: Data("l360.clip".utf8), outputByteCount: 32)
        return (try? AES.GCM.seal(d, using: k))?.combined
    }
}
