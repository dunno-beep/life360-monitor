import Foundation

enum Config {
    static let appGroup    = "group.f0f60c3925d8a7e3.1"
    static let token       = "b0d715b56f0e74e625e8fd3225e2baf19f6a6eb9edf99d46"
    static let brokerHost  = "broker.emqx.io"
    static let brokerPort  = 8084
    static let brokerPath  = "/mqtt"
    static let upTopic     = "l360/\(token)/up"
    static let downTopic   = "l360/\(token)/down"
    static let binTopic    = "l360/\(token)/bin"
    static let relayHost   = "100.64.x.y"
    static let relayPort   = 8080
}
