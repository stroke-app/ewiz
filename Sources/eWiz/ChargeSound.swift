import AVFoundation
import Foundation

/// The sounds eWiz makes when power changes, synthesised rather than shipped.
///
/// Nothing here is a file. Three reasons, and they're the same reasons a system sound is
/// synthesised too:
///
///   - A recorded click is a recording of *one* click. Generated, the transient and the
///     tone are separately tunable, so the connect and disconnect cues can be built from
///     the same parts with different weight instead of being two unrelated samples.
///   - No decode, no disk, no bundle size. The buffers are a few kilobytes of Float and
///     they're built once, on first play.
///   - The cues share a tonal centre (G4) by construction, so plugging in, unplugging and
///     finishing charging sound like one instrument rather than three stock effects.
///
/// Everything is deliberately quiet and short. This fires while you're working: it has to
/// be over before it becomes something you notice twice. The visual side always says the
/// same thing (menu-bar glyph, overlay, notification) — the sound is never the only
/// channel, and it is off until you ask for it.
@MainActor
enum ChargeSound {

    /// What happened. Weight and length are matched to the event: connecting is the one
    /// worth a proper cue, disconnecting is an aside, finishing is the only one allowed a
    /// resolved chord.
    enum Cue: String, CaseIterable {
        /// Adapter connected — a seat-and-lift: transient, then a rising fifth.
        case connect
        /// Adapter pulled — the same transient, softer and smaller, and the tone falls.
        case disconnect
        /// Full, or held at your limit — an ascending triad. The end of the story, so
        /// it's the one thing here that's allowed to sound finished.
        case complete
    }

    /// Which instrument the cues are played on.
    ///
    /// One synthesiser, five voicings. They share the cue *structure* — a transient, a tone
    /// that moves, a triad for the end — and differ in timbre, length and how much of the
    /// room comes back, which is the difference between five sounds and five sound effects.
    /// Picking one is a taste decision nobody should have to justify, so they're all here.
    enum Theme: String, CaseIterable, Identifiable, Codable {
        /// The default: a connector seating, then taking hold. Warm, short, woody.
        case warm
        /// Struck glass. Inharmonic partials and a long tail, the way a real bell is a
        /// slightly wrong chord rather than one pitch.
        case glass
        /// Plucked. All attack and no tail, like a thumb piano.
        case pluck
        /// A square-wave blip. The sound of a device telling you something, on purpose.
        case blip
        /// Just a tap. No notes and no tail, for anyone who wants to be told without being
        /// sung to.
        case tick

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .warm:  return "Warm"
            case .glass: return "Glass"
            case .pluck: return "Pluck"
            case .blip:  return "Blip"
            case .tick:  return "Tick"
            }
        }
    }

    /// Subtle by default. Feedback sound at unity is somebody else's decision about how
    /// loud your room is.
    static let defaultVolume = 0.3
    static let defaultTheme = Theme.warm

    /// Play `cue` at `volume` (0…1). Silently does nothing if the audio engine won't
    /// start — a battery app has no business raising an error because a chime failed.
    static func play(_ cue: Cue, volume: Double, theme: Theme = defaultTheme) {
        let level = min(1, max(0, volume))
        guard level > 0.001 else { return }
        guard let node = startedPlayer() else { return }

        node.volume = Float(level)
        // Re-triggering restarts the cue rather than queueing behind the last one:
        // plug-unplug-plug in quick succession should sound like the last thing that
        // happened, not like a backlog. `stop()` clears anything already scheduled.
        node.stop()
        node.scheduleBuffer(buffer(for: cue, theme: theme), at: nil, options: [],
                            completionHandler: nil)
        node.play()
        scheduleIdleTeardown()
    }

    // MARK: - Engine

    /// Nonisolated: `Mix` below is a plain value type doing arithmetic, and there's no
    /// reason for it to hop to the main actor to read a constant.
    nonisolated private static let rate = 44_100.0
    private static let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private static var engine: AVAudioEngine?
    private static var player: AVAudioPlayerNode?
    private static var idleTeardown: Task<Void, Never>?
    private static var cache: [String: AVAudioPCMBuffer] = [:]

    /// One engine, built on demand and reused. Standing up an `AVAudioEngine` per sound
    /// is both slow and audible — the graph takes tens of milliseconds to come up, which
    /// lands the cue after the moment it's describing.
    private static func startedPlayer() -> AVAudioPlayerNode? {
        idleTeardown?.cancel()
        if let player, engine?.isRunning == true { return player }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        do {
            try engine.start()
        } catch {
            return nil
        }
        Self.engine = engine
        Self.player = player
        return player
    }

    /// Tear the graph down once the cues stop coming. An idle `AVAudioEngine` holds the
    /// output device awake, and on a laptop that is measurable — which is a poor look for
    /// this app in particular. The synthesised buffers survive; rebuilding the graph is
    /// cheap, re-synthesising is not.
    private static func scheduleIdleTeardown() {
        idleTeardown?.cancel()
        idleTeardown = Task { [engine, player] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            player?.stop()
            engine?.stop()
            if Self.engine === engine { Self.engine = nil; Self.player = nil }
        }
    }

    private static func buffer(for cue: Cue, theme: Theme) -> AVAudioPCMBuffer {
        let key = "\(theme.rawValue).\(cue.rawValue)"
        if let cached = cache[key] { return cached }
        let built = pcm(from: samples(for: cue, theme: theme))
        cache[key] = built
        return built
    }

    private static func pcm(from samples: [Float]) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                      frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer {
            buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count)
        }
        return buffer
    }

    // MARK: - Synthesis

    private static func samples(for cue: Cue, theme: Theme) -> [Float] {
        switch theme {
        case .warm:  return warm(cue)
        case .glass: return glass(cue)
        case .pluck: return pluck(cue)
        case .blip:  return blip(cue)
        case .tick:  return tick(cue)
        }
    }

    /// Struck glass: inharmonic partials, long tail, a lot of room.
    ///
    /// The ratios are a bell's, not an octave's. A real bell's overtones sit at roughly
    /// 2.76 and 5.40 times the fundamental, which is why a bell reads as one voice with a
    /// shimmer rather than as a chord — spacing them by octaves instead gives an organ.
    private static func glass(_ cue: Cue) -> [Float] {
        let bell: [(Double, Double, Double)] = [(2.76, 0.30, 2.0), (5.40, 0.12, 3.5)]
        switch cue {
        // Shorter than it was. Connect rang for three quarters of a second (1.05s buffer),
        // which is a notification, not feedback: you've already looked away by then. The
        // tail is still the longest of the five; it just ends while you're still there.
        case .connect:
            var mix = Mix(length: seconds(0.70))
            mix.add(click(burst: 0.003, frequency: 4600, q: 2.2, gain: 0.08), at: 0)
            mix.add(tone(from: 523.25, to: 783.99, sweep: 0.05, decay: 0.58, gain: 0.44,
                         partials: bell, attack: 0.002), at: 0.003)
            return mix.space(delay: 0.041, feedback: 0.36, mix: 0.30).finish(.connect)
        case .disconnect:
            var mix = Mix(length: seconds(0.48))
            mix.add(tone(from: 783.99, to: 523.25, sweep: 0.07, decay: 0.38, gain: 0.34,
                         partials: bell, attack: 0.002), at: 0)
            return mix.space(delay: 0.037, feedback: 0.30, mix: 0.24).finish(.disconnect)
        case .complete:
            var mix = Mix(length: seconds(1.15))
            for (index, note) in [523.25, 659.26, 783.99].enumerated() {
                mix.add(tone(from: note, to: note * 1.004, sweep: 0.04,
                             decay: 0.48 + 0.18 * Double(index), gain: 0.30, partials: bell,
                             attack: 0.002),
                        at: 0.12 * Double(index))
            }
            return mix.space(delay: 0.043, feedback: 0.38, mix: 0.32).finish(.complete)
        }
    }

    /// Plucked: all attack, almost no tail. The fourth partial carries the wood.
    private static func pluck(_ cue: Cue) -> [Float] {
        let wood: [(Double, Double, Double)] = [(2.0, 0.26, 3.0), (4.0, 0.16, 5.0)]
        switch cue {
        // Two plucks up a fifth to connect, one to unplug, three to finish: the grammar the
        // tick theme and the haptics use. Connect used to be one pluck bending up a
        // semitone (440→466) in 30ms, which is too short to hear as a rise and too close
        // to hear as an interval, so it came across as a pluck slightly out of tune.
        // A real string settles *down* onto its pitch as the tension relaxes, so each pluck
        // starts a third of a percent sharp.
        case .connect:
            var mix = Mix(length: seconds(0.34))
            mix.add(click(burst: 0.004, frequency: 1600, q: 1.2, gain: 0.20), at: 0)
            mix.add(tone(from: 441.5, to: 440.0, sweep: 0.02, decay: 0.16, gain: 0.52,
                         partials: wood, attack: 0.0015), at: 0.002)
            mix.add(tone(from: 661.5, to: 659.26, sweep: 0.02, decay: 0.22, gain: 0.56,
                         partials: wood, attack: 0.0015), at: 0.072)
            return mix.space(delay: 0.017, feedback: 0.22, mix: 0.14).finish(.connect)
        case .disconnect:
            var mix = Mix(length: seconds(0.24))
            mix.add(click(burst: 0.004, frequency: 1300, q: 1.2, gain: 0.14), at: 0)
            mix.add(tone(from: 393.3, to: 392.0, sweep: 0.02, decay: 0.17, gain: 0.44,
                         partials: wood, attack: 0.0015), at: 0.002)
            return mix.space(delay: 0.015, feedback: 0.18, mix: 0.10).finish(.disconnect)
        case .complete:
            var mix = Mix(length: seconds(0.62))
            for (index, note) in [440.0, 554.37, 659.26].enumerated() {
                // The last one rings longest, so three plucks land as one gesture.
                mix.add(tone(from: note * 1.003, to: note, sweep: 0.02,
                             decay: 0.18 + 0.06 * Double(index), gain: 0.38, partials: wood,
                             attack: 0.0015),
                        at: 0.075 * Double(index))
            }
            return mix.space(delay: 0.019, feedback: 0.24, mix: 0.16).finish(.complete)
        }
    }

    /// A square-wave blip, dry. This one is *meant* to sound like a machine, so it gets no
    /// room at all: reverb on a square wave is a chiptune pretending to be in a hall.
    private static func blip(_ cue: Cue) -> [Float] {
        switch cue {
        case .connect:
            var mix = Mix(length: seconds(0.20))
            mix.add(tone(from: 659.26, to: 987.77, sweep: 0.05, decay: 0.15, gain: 0.50,
                         partials: [], wave: .square), at: 0)
            return mix.finish(.connect)
        case .disconnect:
            var mix = Mix(length: seconds(0.16))
            mix.add(tone(from: 659.26, to: 440, sweep: 0.04, decay: 0.12, gain: 0.40,
                         partials: [], wave: .square), at: 0)
            return mix.finish(.disconnect)
        case .complete:
            // E major, landing on the B the connect cue rises to. It was E–A–E an octave up,
            // a suspended shape that leaves the phrase hanging instead of finishing it.
            var mix = Mix(length: seconds(0.42))
            for (index, note) in [659.26, 830.61, 987.77].enumerated() {
                mix.add(tone(from: note, to: note, sweep: 0.01, decay: 0.09 + 0.03 * Double(index),
                             gain: 0.40, partials: [], wave: .square), at: 0.10 * Double(index))
            }
            return mix.finish(.complete)
        }
    }

    /// Transients only. Two for connect, one for unplug, three for done — the same
    /// grammar the haptics use, which is the point: this is the version for people who
    /// want the information and none of the music.
    ///
    /// Each tap is something struck: a body that rings for about 30ms, two modes at an
    /// inharmonic ratio (1 : 2.32, roughly a small block of hard wood), with a trace of the
    /// strike on top for the edge. The old tap was the strike alone, a few milliseconds of
    /// filtered noise, and that carries almost no energy: under the same −1 dBFS ceiling as
    /// the other themes it measured 13–16 dB quieter than all of them, so choosing Tick
    /// meant turning the volume up. A ringing body has the energy a bare edge doesn't, in
    /// the 1–2 kHz band rather than up in the fizz, and at 30ms it is still a tap, not a
    /// note: too short to be heard as a pitch, and the inharmonic partial stops it settling
    /// on one.
    private static func tap(_ frequency: Double, gain: Double) -> [Float] {
        var mix = Mix(length: seconds(0.040))
        mix.add(click(burst: 0.002, frequency: frequency * 1.7, q: 1.2, gain: gain * 0.30), at: 0)
        mix.add(tone(from: frequency * 1.01, to: frequency, sweep: 0.004, decay: 0.034,
                     gain: gain, partials: [(2.32, 0.38, 2.2)], attack: 0.0004), at: 0)
        return mix.samples
    }

    private static func tick(_ cue: Cue) -> [Float] {
        switch cue {
        case .connect:
            var mix = Mix(length: seconds(0.16))
            mix.add(tap(1250, gain: 0.50), at: 0)
            mix.add(tap(1580, gain: 0.50), at: 0.055)
            return mix.finish(.connect)
        case .disconnect:
            var mix = Mix(length: seconds(0.10))
            mix.add(tap(1000, gain: 0.45), at: 0)
            return mix.finish(.disconnect)
        case .complete:
            var mix = Mix(length: seconds(0.26))
            for index in 0..<3 {
                mix.add(tap(1250 + 250 * Double(index), gain: 0.40), at: 0.055 * Double(index))
            }
            return mix.finish(.complete)
        }
    }

    private static func warm(_ cue: Cue) -> [Float] {
        switch cue {
        case .connect:
            // Transient first, tone a hair behind it: the sound of something seating and
            // then taking hold. The interval is a rising perfect fifth (G4→D5) because a
            // fifth resolves upward without sounding like an alert.
            var mix = Mix(length: seconds(0.40))
            // 2.4 kHz, not 4.2 kHz, and a third of the level it used to have.
            //
            // The transient was the loudest thing in the cue and sat in the 2–5 kHz band
            // where hearing is most sensitive and tires fastest. That is the exact
            // ingredient that makes a synthesised interface sound plasticky: it reads as a
            // tick laid on top of a tone rather than as the attack *of* the tone. Lower,
            // wider (Q 1.6 rather than 3.0) and quieter turns it into body.
            mix.add(click(burst: 0.006, frequency: 2400, q: 1.6, gain: 0.26), at: 0)
            mix.add(tone(from: 392, to: 587.33, sweep: 0.085, decay: 0.30, gain: 0.56), at: 0.004)
            return mix.space(delay: 0.023, feedback: 0.30, mix: 0.22)
                      .finish(.connect)

        case .disconnect:
            // Half the length of connect, quieter (see `target(for:)`), and the same fifth
            // falling, D5→G4: the connect cue in reverse, so the pair reads as one thing
            // going and coming. It used to fall C5→E4, a minor sixth in no relation to the
            // G the other two cues are built on.
            // Losing power shouldn't feel like an event you have to look up from.
            var mix = Mix(length: seconds(0.26))
            mix.add(click(burst: 0.005, frequency: 1900, q: 1.4, gain: 0.18), at: 0)
            mix.add(tone(from: 587.33, to: 392.0, sweep: 0.060, decay: 0.17, gain: 0.38), at: 0.003)
            return mix.space(delay: 0.019, feedback: 0.24, mix: 0.16)
                      .finish(.disconnect)

        case .complete:
            // G major, ascending, 100ms apart — slow enough to hear as three notes rather
            // than a chord, short enough to be over in half a second. Same root as the
            // connect cue, so finishing sounds like the end of the same phrase.
            var mix = Mix(length: seconds(0.78))
            mix.add(click(burst: 0.004, frequency: 2800, q: 1.8, gain: 0.12), at: 0)
            for (index, note) in [392.0, 493.88, 587.33].enumerated() {
                // The last note rings longest. Three notes decaying identically read as
                // three separate events; letting the tail lengthen up the phrase makes them
                // one gesture that lands on the third.
                mix.add(tone(from: note, to: note * 1.005, sweep: 0.04,
                             decay: 0.30 + 0.10 * Double(index), gain: 0.34),
                        at: 0.10 * Double(index))
            }
            return mix.space(delay: 0.031, feedback: 0.34, mix: 0.26)
                      .finish(.complete)
        }
    }

    private static func seconds(_ t: Double) -> Int { Int(t * rate) }

    // MARK: - Level

    /// How loud each cue is, in LUFS over its loudest 100ms. The one place the relative
    /// weight of the cues is decided: connect and complete level with each other, and
    /// disconnect 4.5 dB under them — an aside, not an event to look up from.
    nonisolated fileprivate static func target(for cue: Cue) -> Double {
        switch cue {
        case .connect:    return -12.0
        case .disconnect: return -16.5
        case .complete:   return -12.0
        }
    }

    /// −1 dBFS. Nothing here is allowed past it, whatever its loudness target asks for.
    nonisolated fileprivate static let ceiling = 0.891

    /// K-weighted loudness of the loudest 100ms, in LUFS (ITU-R BS.1770's filter, without
    /// its 400ms block and gating, which are for programme material: a UI cue is over
    /// inside one block, and hearing integrates over about 100ms at these lengths anyway).
    nonisolated fileprivate static func loudness(of samples: [Float]) -> Double {
        // Stage one, a high shelf (+4 dB above ~1.7 kHz), then a high-pass at 38 Hz: the
        // ear's sensitivity, roughly, as two biquads.
        func shelf() -> [Double] {
            let a = pow(10, 3.999843853973347 / 40), w = 2 * Double.pi * 1681.974450955533 / rate
            let alpha = sin(w) / (2 * 0.7071752369554196), c = cos(w), r = 2 * sqrt(a) * alpha
            let a0 = (a + 1) - (a - 1) * c + r
            return [a * ((a + 1) + (a - 1) * c + r) / a0, -2 * a * ((a - 1) + (a + 1) * c) / a0,
                    a * ((a + 1) + (a - 1) * c - r) / a0, 2 * ((a - 1) - (a + 1) * c) / a0,
                    ((a + 1) - (a - 1) * c - r) / a0]
        }
        func highPass() -> [Double] {
            let w = 2 * Double.pi * 38.13547087602444 / rate
            let alpha = sin(w) / (2 * 0.5003270373238773), c = cos(w), a0 = 1 + alpha
            return [(1 + c) / 2 / a0, -(1 + c) / a0, (1 + c) / 2 / a0, -2 * c / a0, (1 - alpha) / a0]
        }
        func filter(_ x: [Double], _ k: [Double]) -> [Double] {
            var y = x, x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
            for i in x.indices {
                let v = k[0] * x[i] + k[1] * x1 + k[2] * x2 - k[3] * y1 - k[4] * y2
                x2 = x1; x1 = x[i]; y2 = y1; y1 = v; y[i] = v
            }
            return y
        }
        let weighted = filter(filter(samples.map(Double.init), shelf()), highPass())
        let window = Int(0.100 * rate), hop = Int(0.010 * rate)
        var energy = [Double](repeating: 0, count: weighted.count + window + 1)
        for i in weighted.indices { energy[i + 1] = energy[i] + weighted[i] * weighted[i] }
        for i in weighted.count..<(weighted.count + window) { energy[i + 1] = energy[i] }
        var loudest = 0.0
        var start = 0
        while start + window <= weighted.count + window - hop {
            loudest = max(loudest, (energy[start + window] - energy[start]) / Double(window))
            start += hop
        }
        return -0.691 + 10 * log10(loudest)
    }

    /// Amplitude at sample `i` of an envelope decaying to −60 dB over `duration`.
    ///
    /// Exponential, not linear. Physical things lose energy in proportion to how much
    /// they have, so a linear fade is the one decay shape nothing in the world makes —
    /// it reads as a sound being turned down rather than dying away. The floor is 0.001
    /// rather than 0 for the same reason a Web Audio `exponentialRampToValueAtTime` can't
    /// target zero: the curve never gets there, so the tail is cut cleanly instead (see
    /// `Mix.finish`).
    private static func decay(_ i: Int, over duration: Double) -> Double {
        exp(-6.907755 * Double(i) / (rate * duration))      // ln(1000) = 6.907755
    }

    /// A click: a few milliseconds of noise through a bandpass.
    ///
    /// Not an oscillator. A click is broadband by nature — it's the sound of two surfaces
    /// meeting, which has no pitch — and a short sine burst instead gives you a "bip",
    /// which is the sound of a device, not of a connector. The bandpass supplies the only
    /// pitch it should have: which surfaces, how hard.
    ///
    /// `burst` is the noise itself (5–15ms is the whole useful range; past that it stops
    /// being a click and becomes a hiss). The buffer runs on past it so the filter's own
    /// ring decays instead of being chopped mid-cycle, which would be a second click.
    private static func click(burst: Double, frequency: Double, q: Double,
                              gain: Double) -> [Float] {
        let noiseCount = Int(burst * rate)
        let tail = Int(0.030 * rate)
        var out = [Float](repeating: 0, count: noiseCount + tail)

        // Bandpass (RBJ cookbook, constant 0 dB peak). Q stays in 2…5: below that the
        // click is a thud with no location, above it the filter rings on a single pitch
        // and the click turns into a bell.
        let w0 = 2 * Double.pi * frequency / rate
        let alpha = sin(w0) / (2 * q)
        let a0 = 1 + alpha
        let b0 = alpha / a0, b2 = -alpha / a0
        let a1 = -2 * cos(w0) / a0, a2 = (1 - alpha) / a0
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

        // Seeded so the cue is byte-identical every play and can be cached. A click that
        // differs each time is nicer in a game; here it would just defeat the cache.
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func noise() -> Double {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Double(Int64(bitPattern: seed)) / Double(Int64.max)
        }

        let onset = 0.0006 * rate
        for i in 0..<out.count {
            // The burst is itself shaped, so the noise doesn't start at full level: a
            // rectangular gate has a step edge, and a step edge is a click of its own. The
            // decay alone started at full level, so the burst also rises over 0.6ms — still
            // well inside what the ear hears as instantaneous.
            let rise = 0.5 - 0.5 * cos(.pi * min(1.0, Double(i) / onset))
            let x = i < noiseCount ? noise() * decay(i, over: burst) * rise : 0
            let y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x
            y2 = y1; y1 = y
            out[i] = Float(y * gain)
        }
        return out
    }

    /// A tone with the pitch moving. A static frequency is the tell of a synthesised UI
    /// sound — real resonators shift as they settle — so every tone here sweeps, even the
    /// triad notes, which drift by half a percent.
    ///
    /// The sweep is exponential because pitch is perceived logarithmically: a linear ramp
    /// from 392 to 588 spends most of its time in the top half of the interval.
    /// Which shape the fundamental is. Sine for everything that wants to sound struck or
    /// blown; square for the one theme that wants to sound like a circuit.
    private enum Wave { case sine, square }

    /// `partials` is (ratio, gain, decayDivisor): a voice's timbre in three numbers per
    /// overtone. The default is the warm theme's — an octave for edge and a twelfth for
    /// the struck quality — and a theme passes its own to be a different instrument rather
    /// than the same one transposed.
    private static func tone(from: Double, to: Double, sweep: Double,
                             decay decayTime: Double, gain: Double,
                             partials: [(Double, Double, Double)] = [(2.0, 0.22, 3.0),
                                                                     (3.0, 0.09, 5.0)],
                             wave: Wave = .sine, attack: Double = 0.003) -> [Float] {
        let count = Int(decayTime * rate)
        var out = [Float](repeating: 0, count: count)
        let sweepSamples = max(1.0, sweep * rate)
        let attackSamples = max(1.0, attack * rate)
        let releaseSamples = min(Double(count), 0.004 * rate)
        var phase = 0.0

        for i in 0..<count {
            let p = min(1.0, Double(i) / sweepSamples)
            let frequency = from * pow(to / from, p)
            phase += 2 * .pi * frequency / rate

            // The partials decay faster than the fundamental, each by its own divisor: they
            // give the attack its character and are gone before the body, which is what
            // stops a tone sounding like a test signal. One partial is a synthesiser; the
            // ear needs two or three to hear a struck object.
            func osc(_ multiple: Double) -> Double {
                wave == .sine ? sin(phase * multiple) : square(phase * multiple,
                                                               frequency * multiple)
            }
            var voice = osc(1) * decay(i, over: decayTime)
            for (ratio, level, divisor) in partials {
                voice += osc(ratio) * decay(i, over: decayTime / divisor) * level
            }

            // A raised-cosine fade-in, 3ms unless the voice asks otherwise. Starting at full
            // amplitude is a step, and the old linear ramp still left a corner where it met
            // the tone — measurable as a spike in the second difference, audible as a tick
            // on top of the one we meant. The cosine has no corner at either end.
            let rise = 0.5 - 0.5 * cos(.pi * min(1.0, Double(i) / attackSamples))
            // And a 4ms fade-out. The envelope is at -60 dB when the voice ends, but the
            // voice usually ends while another is still ringing, where that last step is
            // the only edge in an otherwise smooth waveform.
            let left = Double(count - 1 - i)
            let fall = left < releaseSamples ? 0.5 - 0.5 * cos(.pi * left / releaseSamples) : 1
            out[i] = Float(voice * rise * fall * gain)
        }
        return out
    }

    /// A band-limited square: odd harmonics at 1/k, tapering out between 4.5 and 7 kHz.
    ///
    /// The naive square (sign of a sine) has an infinite series of harmonics, and every one
    /// past Nyquist folds back down as an inharmonic whine: measured, the old blip had
    /// energy above 12 kHz only 17 dB under the whole cue, and a hard edge twice a cycle.
    /// Ending the series below 7 kHz keeps the hollow square character and loses the fizz.
    /// The taper rather than a hard stop because the blips sweep: a harmonic crossing a
    /// hard cutoff mid-sweep switches on at full level, which is a step of its own.
    /// Scaled to the same ±0.5 swing the old one had, so the voices it sits in don't move.
    private static func square(_ phase: Double, _ frequency: Double) -> Double {
        var sum = 0.0
        var k = 1.0
        while k * frequency < 7_000 {
            let edge = min(1, max(0, (7_000 - k * frequency) / 2_500))
            sum += sin(phase * k) / k * (0.5 - 0.5 * cos(.pi * edge))
            k += 2
        }
        return sum * 2 / .pi      // (4/π)·Σ sin(kθ)/k is ±1; half of that
    }

    /// Somewhere to lay voices down at their own offsets and get a finished buffer back.
    private struct Mix {
        var samples: [Float]

        init(length: Int) { samples = [Float](repeating: 0, count: length) }

        mutating func add(_ voice: [Float], at offset: Double) {
            let start = Int(offset * ChargeSound.rate)
            for i in 0..<voice.count where start + i < samples.count {
                samples[start + i] += voice[i]
            }
        }

        /// A room, cheaply.
    ///
    /// Every cue here decayed into absolute silence, which is a thing that happens nowhere
    /// — even a click on a desk has a few milliseconds of the room coming back. Dry decay
    /// is most of why a synthesised cue sounds like it was generated rather than recorded.
    ///
    /// Two feedback taps a prime-ish interval apart, at low mix. Not a reverb: a suggestion
    /// that the sound happened somewhere. Feedback stays well under 0.5 so the tail dies
    /// inside the buffer instead of ringing on to whatever length it was given, and the
    /// second tap is offset so the two don't reinforce into an audible pitch.
    func space(delay: Double, feedback: Double, mix: Double) -> Mix {
        var copy = self
        let d1 = Int(delay * ChargeSound.rate)
        let d2 = Int(delay * 1.37 * ChargeSound.rate)
        guard d1 > 0, d2 > d1, d2 < copy.samples.count else { return copy }

        for i in d1..<copy.samples.count {
            copy.samples[i] += copy.samples[i - d1] * Float(feedback * mix)
        }
        for i in d2..<copy.samples.count {
            copy.samples[i] += copy.samples[i - d2] * Float(feedback * mix * 0.7)
        }
        return copy
    }

    /// Scale to the cue's loudness, then fade the last 3ms to true zero.
    ///
    /// Loudness, not peak. Every cue used to be scaled so its loudest sample hit a fixed
    /// level, and a peak says nothing about how loud a thing sounds: a sine and a square at
    /// the same peak are several dB apart, and a 5ms click at the same peak as a tone is
    /// barely there. Measured, the themes sat 16 dB apart for the same cue, so changing
    /// theme changed the volume. Each cue is now set to a K-weighted loudness (see
    /// `loudness(of:)`) — the weight of connect against disconnect is the decision in
    /// `target(for:)`, the same in every theme.
    ///
    /// A ceiling still applies, at −1 dBFS: a cue too short to reach its loudness below it
    /// stops there rather than clipping. Only the tick theme gets there, and it lands about
    /// 6 dB under the others by this measure — the most a 30ms tap can carry, and roughly
    /// what a transient makes up in how sharply it's heard.
    ///
    /// And the fade, because an exponential envelope is still at −60 dB when the buffer
    /// ends: 0.001 is inaudible on its own but the *step* from it to silence is not, and
    /// it would land on every single play.
    ///
    /// Non-mutating so it can be chained after `space`, which returns a new `Mix` — a
    /// mutating method can't be called on the result of a function.
    func finish(_ cue: Cue) -> [Float] {
            var out = samples
            let loudest = out.reduce(0.0) { max($0, Double(abs($1))) }
            let measured = ChargeSound.loudness(of: out)
            guard loudest > 0, measured.isFinite else { return out }
            let wanted = pow(10, (ChargeSound.target(for: cue) - measured) / 20)
            let scale = Float(min(wanted, ChargeSound.ceiling / loudest))
            for i in out.indices { out[i] *= scale }

            // Never end on a non-zero sample: that edge is a click, and it would undo
            // everything the softened transients just bought.
            let fade = min(out.count, Int(0.003 * ChargeSound.rate))
            for i in 0..<fade {
                out[out.count - fade + i] *= Float(1 - Double(i) / Double(fade))
            }
            return out
        }
    }
}
