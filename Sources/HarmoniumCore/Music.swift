import Foundation

public enum Music {
    public static let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    // Lowercase = komal, "Ma'" = tivra.
    public static let sargam = ["Sa", "re", "Re", "ga", "Ga", "ma", "Ma'", "Pa", "dha", "Dha", "ni", "Ni"]

    public static func frequency(midi: Double) -> Double {
        440 * pow(2, (midi - 69) / 12)
    }

    public static func isBlack(_ midi: Int) -> Bool {
        [1, 3, 6, 8, 10].contains(((midi % 12) + 12) % 12)
    }

    // ANSI key codes (layout-independent); Z row starts at base C, Q row one octave up.
    public static let keyCodeOffsets: [UInt16: Int] = [
        6: 0, 1: 1, 7: 2, 2: 3, 8: 4, 9: 5, 5: 6, 11: 7, 4: 8, 45: 9, 38: 10, 46: 11,
        43: 12, 37: 13, 47: 14, 41: 15, 44: 16,
        12: 12, 19: 13, 13: 14, 20: 15, 14: 16, 15: 17, 23: 18, 17: 19, 22: 20, 16: 21,
        26: 22, 32: 23, 34: 24, 25: 25, 31: 26, 29: 27, 35: 28, 33: 29, 24: 30, 30: 31,
    ]
}
