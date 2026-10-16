import HarmoniumCore
import XCTest

final class CoreTests: XCTestCase {
    func testFrequency() {
        XCTAssertEqual(Music.frequency(midi: 69), 440, accuracy: 1e-9)
        XCTAssertEqual(Music.frequency(midi: 60), 261.6256, accuracy: 1e-3)
    }

    func testRenderProducesBoundedSoundThenSilence() {
        let synth = Synth(sampleRate: 48_000)
        var buf = [Float](repeating: 0, count: 4800)
        synth.noteOn(key: 60)
        buf.withUnsafeMutableBufferPointer { synth.render(into: $0.baseAddress!, frames: $0.count) }
        XCTAssertGreaterThan(buf.map(abs).max()!, 0.05)
        XCTAssertLessThanOrEqual(buf.map(abs).max()!, 1)

        synth.noteOff(key: 60)
        for _ in 0..<20 { buf.withUnsafeMutableBufferPointer { synth.render(into: $0.baseAddress!, frames: $0.count) } }
        XCTAssertLessThan(buf.map(abs).max()!, 1e-3)
    }

    func testBellowsPumpsOnLidTravelAndDrainsWithNotes() {
        var b = Bellows()
        b.update(angle: 100, dt: 1.0 / 60, notes: 0)
        for _ in 0..<120 { b.update(angle: 100 + Double(Int.random(in: 0...1)), dt: 1.0 / 60, notes: 0) }
        XCTAssertEqual(b.pressure, 0, "sensor jitter must not pump")

        for i in 0..<60 { b.update(angle: 100 + Double(i % 20) * (i / 20 % 2 == 0 ? 1 : -1), dt: 1.0 / 60, notes: 0) }
        b.update(angle: 130, dt: 1.0 / 60, notes: 0)
        XCTAssertGreaterThan(b.pressure, 0.3)

        let full = b.pressure
        for _ in 0..<60 { b.update(angle: 130, dt: 1.0 / 60, notes: 3) }
        XCTAssertLessThan(b.pressure, full - 0.3)
        for _ in 0..<600 { b.update(angle: 130, dt: 1.0 / 60, notes: 3) }
        XCTAssertEqual(b.gain, 0)
    }

    func testLidAngleWalksTheMajorScaleWithHysteresis() {
        var m = LidMelody()
        XCTAssertEqual(m.semitone(for: 23), 0)
        XCTAssertEqual(m.semitone(for: 29), 2)
        XCTAssertEqual(m.semitone(for: 35), 4)
        XCTAssertEqual(m.semitone(for: 41), 5)
        XCTAssertEqual(m.semitone(for: 20 + 7 * 6 + 3), 12)
        XCTAssertEqual(m.semitone(for: 5), 0)

        _ = m.semitone(for: 33)
        XCTAssertEqual(m.semitone(for: 37.5), 4, "within hysteresis of the boundary at 38°")
        XCTAssertEqual(m.semitone(for: 31.5), 4)
        XCTAssertEqual(m.semitone(for: 40), 5)
    }

    func testRetriggerGlidesWithoutRestartingEnvelope() {
        let synth = Synth(sampleRate: 48_000)
        var buf = [Float](repeating: 0, count: 9600)
        synth.noteOn(key: -1, note: 60)
        buf.withUnsafeMutableBufferPointer { synth.render(into: $0.baseAddress!, frames: $0.count) }
        synth.noteOn(key: -1, note: 62)
        buf.withUnsafeMutableBufferPointer { synth.render(into: $0.baseAddress!, frames: 64) }
        XCTAssertGreaterThan(buf.prefix(64).map(abs).max()!, 0.05, "glide must not drop to silence")
    }

    func testNoAirMeansSilence() {
        let synth = Synth(sampleRate: 48_000)
        synth.setAir(0)
        synth.noteOn(key: 60)
        var buf = [Float](repeating: 0, count: 48_000)
        buf.withUnsafeMutableBufferPointer { synth.render(into: $0.baseAddress!, frames: $0.count) }
        XCTAssertLessThan(buf.suffix(1000).map(abs).max()!, 1e-4)
    }

    func testHighNotesDoNotCrash() {
        let synth = Synth(sampleRate: 44_100)
        var p = Synth.Params()
        p.female = 1
        p.transpose = 11
        synth.setParams(p)
        synth.noteOn(key: 108)
        var buf = [Float](repeating: 0, count: 512)
        buf.withUnsafeMutableBufferPointer { synth.render(into: $0.baseAddress!, frames: $0.count) }
        XCTAssertFalse(buf.contains { $0.isNaN })
    }
}
