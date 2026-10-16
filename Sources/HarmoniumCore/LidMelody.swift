import Foundation

public struct LidMelody {
    public static let lowestAngle = 20.0
    public static let degreesPerNote = 6.0
    // Must exceed the sensor's ±1° jitter so a lid resting on a boundary doesn't flicker between notes.
    static let hysteresis = 1.5
    static let major = [0, 2, 4, 5, 7, 9, 11]

    public private(set) var step: Int?

    public init() {}

    public mutating func semitone(for angle: Double) -> Int {
        let raw = max(0, (angle - LidMelody.lowestAngle) / LidMelody.degreesPerNote)
        if let s = step, raw >= Double(s) - LidMelody.hysteresis / LidMelody.degreesPerNote,
           raw < Double(s + 1) + LidMelody.hysteresis / LidMelody.degreesPerNote {
            return LidMelody.semitone(step: s)
        }
        step = Int(raw)
        return LidMelody.semitone(step: step!)
    }

    static func semitone(step: Int) -> Int {
        12 * (step / 7) + major[step % 7]
    }
}
