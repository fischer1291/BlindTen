@preconcurrency import CoreHaptics
import UIKit

/// SPEC.md haptics: sharp tap on START and STOP, rising rumble during the
/// drumroll, a strong success pattern on DEAD ON, a sad double-buzz on
/// "Lost in time", plus the Heartbeat mode pulse. Custom patterns use Core
/// Haptics; devices without it fall back to UIKit feedback generators.
@MainActor
final class Haptics {
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var tapPattern: CHHapticPattern?
    private var drumrollPlayer: CHHapticAdvancedPatternPlayer?
    private var heartbeatPlayer: CHHapticAdvancedPatternPlayer?
    private let tapGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let landGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    func prepare() {
        tapGenerator.prepare()
        guard supportsHaptics, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.resetHandler = { @Sendable [weak self] in
                Task { @MainActor [weak self] in self?.handleReset() }
            }
            try engine.start()
            self.engine = engine
            tapPattern = try CHHapticPattern(
                events: [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                        ],
                        relativeTime: 0
                    ),
                ],
                parameters: []
            )
        } catch {
            self.engine = nil
        }
    }

    /// Call when a turn screen appears so the START/STOP tap fires without
    /// spin-up delay. UIKit generators only stay prepared for a few seconds.
    func warmUp() {
        tapGenerator.prepare()
        try? engine?.start()
    }

    /// START and STOP. Uses the running Core Haptics engine when it can,
    /// which has no spin-up delay; never blocks on starting the engine.
    func tap() {
        if let engine, let tapPattern,
           let player = try? engine.makePlayer(with: tapPattern),
           (try? player.start(atTime: CHHapticTimeImmediate)) != nil {
            return
        }
        tapGenerator.impactOccurred(intensity: 1.0)
        tapGenerator.prepare()
    }

    /// A rumble that grows from faint to full over `duration`.
    func startDrumroll(duration: TimeInterval) {
        stopDrumroll()
        guard let engine = runningEngine(), duration > 0 else { return }
        let rumble = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
            ],
            relativeTime: 0,
            duration: duration
        )
        let rise = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 0.1),
                CHHapticParameterCurve.ControlPoint(relativeTime: duration * 0.7, value: 0.55),
                CHHapticParameterCurve.ControlPoint(relativeTime: duration, value: 1.0),
            ],
            relativeTime: 0
        )
        do {
            let pattern = try CHHapticPattern(events: [rumble], parameterCurves: [rise])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            drumrollPlayer = player
        } catch {
            drumrollPlayer = nil
        }
    }

    func stopDrumroll() {
        try? drumrollPlayer?.stop(atTime: CHHapticTimeImmediate)
        drumrollPlayer = nil
    }

    /// Heartbeat mode: a "lub-dub" every `interval` seconds until stopped.
    func startHeartbeat(interval: TimeInterval) {
        stopHeartbeat()
        guard let engine = runningEngine(), interval > 0.3 else { return }
        let beats = [(0.0, Float(1.0)), (0.14, Float(0.6))].map { time, intensity in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
                ],
                relativeTime: time
            )
        }
        do {
            let pattern = try CHHapticPattern(events: beats, parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            player.loopEnabled = true
            player.loopEnd = interval
            try player.start(atTime: CHHapticTimeImmediate)
            heartbeatPlayer = player
        } catch {
            heartbeatPlayer = nil
        }
    }

    func stopHeartbeat() {
        try? heartbeatPlayer?.stop(atTime: CHHapticTimeImmediate)
        heartbeatPlayer = nil
    }

    /// DEAD ON: three sharp hits and a swelling buzz.
    func deadOn() {
        guard supportsHaptics else {
            notificationGenerator.notificationOccurred(.success)
            return
        }
        var events = [0.0, 0.09, 0.18].map { time in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                ],
                relativeTime: time
            )
        }
        events.append(
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                ],
                relativeTime: 0.27,
                duration: 0.45
            )
        )
        let fade = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0.27, value: 1.0),
                CHHapticParameterCurve.ControlPoint(relativeTime: 0.72, value: 0.0),
            ],
            relativeTime: 0
        )
        play(events: events, curves: [fade])
    }

    /// Lost in time, misfire, timeout: a dull double-buzz.
    func fail() {
        guard supportsHaptics else {
            notificationGenerator.notificationOccurred(.error)
            return
        }
        let events = [0.0, 0.32].map { time in
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.05),
                ],
                relativeTime: time,
                duration: 0.2
            )
        }
        play(events: events)
    }

    /// Every other result: one firm landing tap.
    func land() {
        landGenerator.impactOccurred()
    }

    private func play(events: [CHHapticEvent], curves: [CHHapticParameterCurve] = []) {
        guard let engine = runningEngine() else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are decoration; never interrupt the game for them.
        }
    }

    /// The engine, restarted if the system stopped it.
    private func runningEngine() -> CHHapticEngine? {
        guard let engine else { return nil }
        do {
            try engine.start()
            return engine
        } catch {
            return nil
        }
    }

    private func handleReset() {
        drumrollPlayer = nil
        heartbeatPlayer = nil
        try? engine?.start()
    }
}
