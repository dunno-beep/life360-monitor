import Foundation
import CryptoKit

enum Config {
    static let appGroup = "group.f0f60c3925d8a7e3.1"

    static let token   = "639a0cfb21944f825c517fc149c8edfcb5b0a70a1d4a5ebe"
    static let viewer  = "41ac53e9189ecef98795170d41b33389908ea7308057a78a"
    static let control = "77635b19c7fae73c52f18d63c3ac6b7e706c4aeba9e745a9"

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
