import AppKit
import AVFoundation
import HarmoniumCore
import SwiftUI

@main
struct HarmoniumApp: App {
    @StateObject private var model = HarmoniumModel()

    var body: some Scene {
        WindowGroup("Harmonium") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1100, minHeight: 440)
        }
        .windowResizability(.contentMinSize)
    }
}

enum LidMode: String, CaseIterable {
    case play = "Play with lid"
    case pump = "Pump with lid"
    case off = "Air always on"
}

@MainActor
final class HarmoniumModel: ObservableObject {
    let engine = AVAudioEngine()
    let reverb = AVAudioUnitReverb()
    let synth: Synth
    @Published var params = Synth.Params() { didSet { synth.setParams(params) } }
    @Published var reverbMix: Float = 25 { didSet { reverb.wetDryMix = reverbMix } }
    @Published var octave = 0 { didSet { if octave != oldValue { releaseAll() } } }
    @Published var showSargam = true
    @Published var pressed: Set<Int> = []
    @Published var audioError: String?
    @Published var lidMode: LidMode {
        didSet {
            if lidMode == .off { synth.setAir(1) }
            if lidMode != .play { stopLidNote() }
        }
    }
    @Published var bellows = Bellows()
    @Published var lidAngle: Double?
    @Published var lidNote: Int?
    let lid = LidSensor()
    private var melody = LidMelody()
    private static let lidVoice = -1

    var lidBellows: Bool { lidMode != .off }
    private var keyMonitor: Any?
    private var bellowsTimer: Timer?

    var baseNote: Int { 48 + 12 * octave }

    init() {
        let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        synth = Synth(sampleRate: rate > 0 ? rate : 48_000)
        lidMode = lid != nil ? .play : .off
        // Reverb rejects mono input (-10868), so render mono and duplicate into both channels.
        let format = AVAudioFormat(standardFormatWithSampleRate: synth.sampleRate, channels: 2)!
        let source = AVAudioSourceNode(format: format) { [synth] _, _, frames, abl in
            let buffers = UnsafeMutableAudioBufferListPointer(abl)
            let left = buffers[0].mData!.assumingMemoryBound(to: Float.self)
            synth.render(into: left, frames: Int(frames))
            buffers[1].mData!.assumingMemoryBound(to: Float.self).update(from: left, count: Int(frames))
            return noErr
        }
        engine.attach(source)
        engine.attach(reverb)
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = reverbMix
        engine.connect(source, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        do { try engine.start() } catch { audioError = "Audio failed to start: \(error.localizedDescription)" }
        synth.setParams(params)
        synth.setAir(lidBellows ? 0 : 1)
        installKeyMonitor()
        startBellows()
    }

    private func startBellows() {
        guard lid != nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickBellows(dt: 1.0 / 60) }
        }
        RunLoop.main.add(timer, forMode: .common)
        bellowsTimer = timer
    }

    private func tickBellows(dt: Double) {
        lidAngle = lid?.angle()
        guard lidBellows else { return }
        if lidMode == .play, let angle = lidAngle {
            let note = baseNote + melody.semitone(for: angle)
            if note != lidNote {
                lidNote = note
                synth.noteOn(key: Self.lidVoice, note: note)
            }
        }
        bellows.update(angle: lidAngle, dt: dt, notes: pressed.count + (lidNote == nil ? 0 : 1))
        synth.setAir(bellows.gain)
    }

    private func stopLidNote() {
        lidNote = nil
        synth.noteOff(key: Self.lidVoice)
    }

    func press(_ key: Int) {
        guard !pressed.contains(key) else { return }
        pressed.insert(key)
        synth.noteOn(key: key)
    }

    func release(_ key: Int) {
        pressed.remove(key)
        synth.noteOff(key: key)
    }

    func releaseAll() {
        pressed.removeAll()
        lidNote = nil
        synth.allOff()
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self, event.modifierFlags.isDisjoint(with: [.command, .control, .option]) else { return event }
            if event.type == .keyDown {
                switch event.keyCode {
                case 123: octave = max(-2, octave - 1); return nil
                case 124: octave = min(2, octave + 1); return nil
                case 126: params.transpose = min(11, params.transpose + 1); return nil
                case 125: params.transpose = max(-11, params.transpose - 1); return nil
                default: break
                }
            }
            guard let offset = Music.keyCodeOffsets[event.keyCode] else { return event }
            if event.type == .keyDown { if !event.isARepeat { press(baseNote + offset) } } else { release(baseNote + offset) }
            return nil
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: HarmoniumModel

    var body: some View {
        VStack(spacing: 0) {
            ControlPanel()
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [Color(red: 0.36, green: 0.18, blue: 0.08), Color(red: 0.24, green: 0.11, blue: 0.05)], startPoint: .top, endPoint: .bottom))
            Rectangle().fill(Color(red: 0.55, green: 0.08, blue: 0.1)).frame(height: 10)
            KeyboardView()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(red: 0.18, green: 0.08, blue: 0.03))
            if let error = model.audioError {
                Text(error).foregroundStyle(.red).padding(6)
            }
            Text("Move the lid to play · Z-row and Q-row play · ←/→ octave · ↑/↓ scale (transpose)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(6)
        }
        .onDisappear { model.releaseAll() }
    }
}

struct ControlPanel: View {
    @EnvironmentObject var model: HarmoniumModel

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            BellowsPanel()
            VStack(alignment: .leading, spacing: 6) {
                Label("Reeds", systemImage: "wind").font(.headline)
                reed("Bass", \.bass)
                reed("Male", \.male)
                reed("Male 2 (beat)", \.male2)
                reed("Female", \.female)
            }
            VStack(alignment: .leading, spacing: 6) {
                Label("Sound", systemImage: "slider.horizontal.3").font(.headline)
                slider("Volume", value: $model.params.volume, in: 0...1)
                slider("Soft / Hard", value: $model.params.tone, in: 0.1...1)
                slider("Reverb", value: $model.reverbMix, in: 0...80)
                slider("Beat (cents)", value: Binding(get: { Float(model.params.beatCents) }, set: { model.params.beatCents = Double($0) }), in: 0...20)
                slider("Bellows attack", value: Binding(get: { Float(model.params.attack) }, set: { model.params.attack = Double($0) }), in: 0.005...0.4)
            }
            VStack(alignment: .leading, spacing: 10) {
                Label("Scale", systemImage: "music.note").font(.headline)
                Stepper("Sa = \(Music.noteNames[((model.params.transpose % 12) + 12) % 12]) (\(model.params.transpose >= 0 ? "+" : "")\(model.params.transpose))",
                        value: $model.params.transpose, in: -11...11)
                Stepper("Octave \(model.octave >= 0 ? "+" : "")\(model.octave)", value: $model.octave, in: -2...2)
                slider("Fine tune (cents)", value: Binding(get: { Float(model.params.tuningCents) }, set: { model.params.tuningCents = Double($0) }), in: -50...50)
                Toggle("Sargam labels", isOn: $model.showSargam)
            }
        }
        .foregroundStyle(Color(red: 0.98, green: 0.92, blue: 0.8))
        .tint(Color(red: 0.95, green: 0.7, blue: 0.3))
    }

    private func reed(_ name: String, _ path: WritableKeyPath<Synth.Params, Float>) -> some View {
        HStack {
            Toggle(name, isOn: Binding(get: { model.params[keyPath: path] > 0 }, set: { model.params[keyPath: path] = $0 ? 0.8 : 0 }))
                .frame(width: 130, alignment: .leading)
            Slider(value: Binding(get: { model.params[keyPath: path] }, set: { model.params[keyPath: path] = $0 }), in: 0...1)
                .frame(width: 100)
                .accessibilityLabel("\(name) gain")
        }
    }

    private func slider(_ name: String, value: Binding<Float>, in range: ClosedRange<Float>) -> some View {
        HStack {
            Text(name).frame(width: 120, alignment: .leading)
            Slider(value: value, in: range).frame(width: 140).accessibilityLabel(name)
        }
    }
}

struct BellowsPanel: View {
    @EnvironmentObject var model: HarmoniumModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Bellows", systemImage: "laptopcomputer").font(.headline)
            if model.lid == nil {
                Text("No lid sensor found.\nAir is always on.")
                    .font(.caption)
                    .opacity(0.8)
            } else {
                Picker("Lid", selection: $model.lidMode) {
                    ForEach(LidMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                HStack(alignment: .bottom, spacing: 10) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.35))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 0.95, green: 0.7, blue: 0.3))
                            .frame(height: 80 * (model.lidBellows ? model.bellows.pressure : 1))
                    }
                    .frame(width: 14, height: 80)
                    .accessibilityElement()
                    .accessibilityLabel("Air pressure")
                    .accessibilityValue("\(Int((model.lidBellows ? model.bellows.pressure : 1) * 100)) percent")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lid \(model.lidAngle.map { "\(Int($0))°" } ?? "–")").monospacedDigit()
                        Text("Air \(Int((model.lidBellows ? model.bellows.pressure : 1) * 100))%").monospacedDigit()
                        Text("Sensitivity").font(.caption).opacity(0.8)
                        Slider(value: $model.bellows.sensitivity, in: 0.3...3).frame(width: 110)
                            .accessibilityLabel("Bellows sensitivity")
                    }
                }
                Text(model.lidMode == .play ? "Open/close the lid to play the scale" : "Rock the lid to pump air")
                    .font(.caption)
                    .opacity(0.8)
            }
        }
        .frame(width: 170, alignment: .leading)
    }
}

struct KeyboardView: View {
    @EnvironmentObject var model: HarmoniumModel
    private let span = 37

    var body: some View {
        GeometryReader { geo in
            let keys = (0..<span).map { model.baseNote + $0 }
            let whites = keys.filter { !Music.isBlack($0) }
            let whiteWidth = geo.size.width / CGFloat(whites.count)
            ZStack(alignment: .topLeading) {
                ForEach(Array(whites.enumerated()), id: \.element) { index, key in
                    KeyView(key: key, label: label(key), black: false)
                        .frame(width: whiteWidth - 2, height: geo.size.height)
                        .offset(x: CGFloat(index) * whiteWidth)
                }
                ForEach(keys.filter(Music.isBlack), id: \.self) { key in
                    let whitesBefore = keys.prefix { $0 < key }.filter { !Music.isBlack($0) }.count
                    KeyView(key: key, label: label(key), black: true)
                        .frame(width: whiteWidth * 0.6, height: geo.size.height * 0.6)
                        .offset(x: CGFloat(whitesBefore) * whiteWidth - whiteWidth * 0.3 - 1)
                }
            }
        }
        .frame(minHeight: 180)
    }

    private func label(_ key: Int) -> String {
        let pc = ((key % 12) + 12) % 12
        return model.showSargam ? Music.sargam[pc] : "\(Music.noteNames[pc])\(key / 12 - 1)"
    }
}

struct KeyView: View {
    @EnvironmentObject var model: HarmoniumModel
    let key: Int
    let label: String
    let black: Bool

    var body: some View {
        let down = model.pressed.contains(key) || model.lidNote == key
        RoundedRectangle(cornerRadius: 4)
            .fill(black
                  ? (down ? Color(white: 0.35) : Color(white: 0.08))
                  : (down ? Color(red: 0.95, green: 0.85, blue: 0.65) : Color(red: 0.99, green: 0.97, blue: 0.92)))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.5)))
            .overlay(alignment: .bottom) {
                Text(label)
                    .font(.system(size: black ? 9 : 11, weight: .medium))
                    .foregroundStyle(black ? .white.opacity(0.8) : .black.opacity(0.6))
                    .padding(.bottom, 6)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in model.press(key) }
                .onEnded { _ in model.release(key) })
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
    }
}
