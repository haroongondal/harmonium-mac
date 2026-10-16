import Foundation
import os

// Reed banks follow the original app's 4-reed model; male2 is detuned against male to produce the "vibrate" beating.
public final class Synth: @unchecked Sendable {
    public struct Params: Sendable {
        public var bass: Float = 0
        public var male: Float = 1
        public var male2: Float = 0.8
        public var female: Float = 0
        public var beatCents: Double = 6
        public var tuningCents: Double = 0
        public var transpose: Int = 0
        public var attack: Double = 0.06
        public var release: Double = 0.15
        public var tone: Float = 0.7
        public var volume: Float = 0.8
        public init() {}
    }

    private struct Voice {
        var key: Int
        var midi: Double
        var phase: (Double, Double, Double, Double) = (0, 0, 0, 0)
        var env: Float = 0
        var gate = true
    }

    static let tableSize = 2048
    static let levelTopHz: [Double] = (0..<9).map { 55 * pow(2, Double($0)) }

    public let sampleRate: Double
    private let tables: [[Float]]
    private let lock = OSAllocatedUnfairLock()
    private var voices: [Voice] = []
    private var params = Params()
    private var lp: Float = 0
    private var air: Float = 1
    private var airTarget: Float = 1

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
        tables = Synth.levelTopHz.map { Synth.reedTable(harmonics: max(1, Int(sampleRate * 0.45 / $0))) }
        voices.reserveCapacity(128)
    }

    static func reedTable(harmonics: Int) -> [Float] {
        let n = min(harmonics, 60)
        var t = [Float](repeating: 0, count: tableSize + 1)
        for i in 0..<tableSize {
            let x = 2 * Double.pi * Double(i) / Double(tableSize)
            var s = 0.0
            for h in 1...n {
                let a = pow(Double(h), -0.85) * (h % 2 == 0 ? 0.7 : 1)
                s += a * sin(Double(h) * x)
            }
            t[i] = Float(s)
        }
        let peak = t.map(abs).max() ?? 1
        for i in 0..<tableSize { t[i] /= peak }
        t[tableSize] = t[0]
        return t
    }

    public func setParams(_ p: Params) { lock.withLock { params = p } }

    public func setAir(_ a: Float) { lock.withLock { airTarget = a } }

    /// Re-triggering a sounding key glides it to the new note without restarting its envelope or phase.
    public func noteOn(key: Int, note: Int? = nil) {
        lock.withLock {
            let midi = Double((note ?? key) + params.transpose) + params.tuningCents / 100
            if let i = voices.firstIndex(where: { $0.key == key }) {
                voices[i].midi = midi
                voices[i].gate = true
            } else {
                voices.append(Voice(key: key, midi: midi))
            }
        }
    }

    public func noteOff(key: Int) {
        lock.withLock { for i in voices.indices where voices[i].key == key { voices[i].gate = false } }
    }

    public func allOff() { lock.withLock { for i in voices.indices { voices[i].gate = false } } }

    public func render(into out: UnsafeMutablePointer<Float>, frames: Int) {
        lock.lock()
        defer { lock.unlock() }
        let p = params
        let attackK = Float(1 - exp(-1 / (p.attack * sampleRate)))
        let releaseK = Float(1 - exp(-1 / (p.release * sampleRate)))
        let gains = (p.bass, p.male, p.male2, p.female)
        let lpK = 0.05 + 0.95 * p.tone * p.tone
        for f in 0..<frames { out[f] = 0 }

        for v in voices.indices {
            var voice = voices[v]
            let base = Music.frequency(midi: voice.midi)
            let incs = (base / 2, base, base * pow(2, p.beatCents / 1200), base * 2)
            let tabs = (table(for: incs.0), table(for: incs.1), table(for: incs.2), table(for: incs.3))
            for f in 0..<frames {
                voice.env += ((voice.gate ? 1 : 0) - voice.env) * (voice.gate ? attackK : releaseK)
                var s: Float = 0
                if gains.0 > 0 { s += gains.0 * lookup(tabs.0, voice.phase.0) }
                if gains.1 > 0 { s += gains.1 * lookup(tabs.1, voice.phase.1) }
                if gains.2 > 0 { s += gains.2 * lookup(tabs.2, voice.phase.2) }
                if gains.3 > 0 { s += gains.3 * lookup(tabs.3, voice.phase.3) }
                out[f] += s * voice.env
                voice.phase.0 = (voice.phase.0 + incs.0 / sampleRate).truncatingRemainder(dividingBy: 1)
                voice.phase.1 = (voice.phase.1 + incs.1 / sampleRate).truncatingRemainder(dividingBy: 1)
                voice.phase.2 = (voice.phase.2 + incs.2 / sampleRate).truncatingRemainder(dividingBy: 1)
                voice.phase.3 = (voice.phase.3 + incs.3 / sampleRate).truncatingRemainder(dividingBy: 1)
            }
            voices[v] = voice
        }
        voices.removeAll { !$0.gate && $0.env < 1e-4 }

        let airK = Float(1 - exp(-1 / (0.03 * sampleRate)))
        for f in 0..<frames {
            lp += (out[f] - lp) * lpK
            air += (airTarget - air) * airK
            out[f] = tanh(lp * 0.18 * p.volume * air)
        }
    }

    private func table(for hz: Double) -> Int {
        Synth.levelTopHz.firstIndex { hz <= $0 } ?? Synth.levelTopHz.count - 1
    }

    @inline(__always) private func lookup(_ t: Int, _ phase: Double) -> Float {
        let pos = phase * Double(Synth.tableSize)
        let i = Int(pos)
        let frac = Float(pos - Double(i))
        return tables[t].withUnsafeBufferPointer { $0[i] + ($0[i + 1] - $0[i]) * frac }
    }
}
