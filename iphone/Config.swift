import Foundation
import CryptoKit

enum Config {
    static let appGroup = "group.f0f60c3925d8a7e3.1"

    static let token   = "f6ab49d305655e5b85d5384e0cfe03dcbc04b64c06c4fb1e"
    static let viewer  = "39fafcec3ecf4a61709f705f5b79e407aa620b55abbc2838"
    static let control = "068985220a827c67d1f0387d730c3f4b04d8c06024ccbcc9"

    static let relayHost = "100.94.117.23"
    static let relayPort = 8080

    static let brokerHost = "broker.emqx.io"
    static let brokerPort = 8084
    static let brokerPath = "/mqtt"

    private static let ns: String = {
        let h = SHA256.hash(data: Data(token.utf8))
        return h.map { String(format: "%02x", $0) }.joined().prefix(24).description
    }()

    static let upTopic   = "l360/\(ns)/up"
    static let downTopic = "l360/\(ns)/down"
    static let binTopic  = "l360/\(ns)/bin"
}
