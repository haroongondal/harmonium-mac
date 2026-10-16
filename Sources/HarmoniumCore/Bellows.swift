import Foundation

public struct Bellows {
    public var pressure = 0.0
    public var sensitivity = 1.0
    private var anchor: Double?

    static let pumpPerDegree = 0.02
    static let leakIdle = 0.05
    static let leakPerNote = 0.12
    // The sensor reports whole degrees and jitters by ±1 at rest; only count real travel.
    static let minStep = 2.0

    public init() {}

    public var gain: Float { Float(min(1, pressure * 1.5)) }

    public mutating func update(angle: Double?, dt: Double, notes: Int) {
        if let angle {
            if let a = anchor, abs(angle - a) >= Bellows.minStep {
                pressure += abs(angle - a) * Bellows.pumpPerDegree * sensitivity
                anchor = angle
            } else if anchor == nil {
                anchor = angle
            }
        }
        pressure -= dt * (Bellows.leakIdle + Bellows.leakPerNote * Double(notes))
        pressure = min(1, max(0, pressure))
    }
}
