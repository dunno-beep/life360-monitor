import Foundation
import CryptoKit

enum Config {
    static let appGroup = "group.f0f60c3925d8a7e3.1"

    static let token   = "b9e6a685352c85b5574ec311b61b06fbb10c2488ca92bc8c"
    static let viewer  = "5402b1fae55b95913634afdd5aa6484bb6c679aced51084f"
    static let control = "a69ed45d8b28fb3dde096eccec49245a5bce43db2a9d7324"

    static let relayHost = "relay.tail6fc991.ts.net"
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
