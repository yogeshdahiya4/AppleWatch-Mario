import Combine
import Foundation
import WatchKit

/// Single-finger joystick model + flick-up jump detection.
///
/// Movement: horizontal drag distance from the press origin maps to an
/// analog axis in [-1, 1] (deadzone in the middle). The press origin is
/// the position the finger first landed — *not* the center of the screen —
/// so any starting point on the bottom 40% of the screen "becomes" the
/// joystick anchor.
///
/// Jump: detected when the finger flicks upward fast enough during a drag
/// without lifting. We track per-frame upward velocity in a small ring
/// buffer and trigger when avg upward velocity > flickThreshold.
@MainActor
final class InputController: ObservableObject {
    /// Visual joystick state for the SwiftUI overlay.
    @Published private(set) var joystick: JoystickState = .idle

    /// Read by GameScene each tick.
    @Published private(set) var moveAxis: CGFloat = 0    // [-1, 1]
    @Published private(set) var jumpHeld: Bool = false   // for variable-height jump

    /// Action stream (jump impulses, pause, power-up) — collected via Combine.
    let jumpEvents = PassthroughSubject<CGFloat, Never>() // payload = flick magnitude (0..1)
    let pauseEvents = PassthroughSubject<Void, Never>()
    let powerUpEvents = PassthroughSubject<Void, Never>()

    // MARK: - Tunables (exposed so QA can dial them in)

    var deadzonePoints: CGFloat = 6
    var maxDragPoints: CGFloat = 60
    /// How far above the joystick origin (in points) before we treat the touch
    /// as "jump pressed". Tuned to work alongside horizontal drag so diagonal
    /// motion (up-right / up-left) is reliable.
    var jumpDragThreshold: CGFloat = 22

    // MARK: - Internal

    private struct DragState {
        var origin: CGPoint
        var current: CGPoint
        var startedAt: TimeInterval
    }

    private var drag: DragState?
    /// Wall-clock timestamp of the last jump emission. While the user keeps
    /// the joystick pushed up the controller fires `jumpEvents` repeatedly,
    /// throttled to one fire per `jumpRefractorySeconds`. Player.tick filters
    /// these against the grounded/coyote-time state so airborne re-triggers
    /// don't actually jump twice.
    private var lastJumpFiredAt: TimeInterval = 0
    /// Min seconds between two repeat-fires while holding up. ~5/sec.
    var jumpRefractorySeconds: TimeInterval = 0.20

    enum JoystickState: Equatable {
        case idle
        case active(origin: CGPoint, thumb: CGPoint)
    }

    // MARK: - Touch handling

    /// Called by the scene/view on touchDown.
    func touchDown(at p: CGPoint, time: TimeInterval) {
        drag = DragState(origin: p, current: p, startedAt: time)
        joystick = .active(origin: p, thumb: p)
        recomputeAxes()
    }

    /// Called every time the finger moves.
    func touchMoved(to p: CGPoint, time _: TimeInterval) {
        guard var d = drag else { return }
        d.current = p
        drag = d
        joystick = .active(origin: d.origin, thumb: p)
        recomputeAxes()
        evaluateJumpIntent()
    }

    func touchUp(at _: CGPoint, time _: TimeInterval) {
        drag = nil
        joystick = .idle
        moveAxis = 0
        jumpHeld = false
    }

    func cancelTouch() {
        drag = nil
        joystick = .idle
        moveAxis = 0
        jumpHeld = false
    }

    // MARK: - Explicit jump button (in addition to flick-up gesture)

    /// Called when the on-screen jump button is pressed.
    func jumpButtonDown() {
        jumpEvents.send(1.0)   // full magnitude
        jumpHeld = true
    }

    /// Called when the jump button is released (variable-height window closes).
    func jumpButtonUp() {
        jumpHeld = false
    }

    /// Virtual-joystick semantics: dragging the finger above the touch origin
    /// expresses jump intent. While held in the upper region, jumps fire at
    /// the refractory cadence (Player.tick gates them on grounded/coyote).
    private func evaluateJumpIntent() {
        guard let d = drag else { jumpHeld = false; return }
        // y-up after view-layer flip: positive = finger above origin
        let dy = d.current.y - d.origin.y
        let pushedUp = dy > jumpDragThreshold
        jumpHeld = pushedUp     // for variable-height jump while held
        guard pushedUp else { return }
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastJumpFiredAt >= jumpRefractorySeconds else { return }
        lastJumpFiredAt = now
        // Magnitude scales with how far up the finger is, capped sensibly.
        let mag = min(1.0, max(0.5, dy / 60))
        jumpEvents.send(mag)
    }

    private func recomputeAxes() {
        guard let d = drag else { moveAxis = 0; return }
        // Horizontal axis is independent of vertical (jump). Diagonal drags
        // (up-and-right, up-and-left) drive both at full strength.
        let dx = d.current.x - d.origin.x
        let signedMag = max(-maxDragPoints, min(maxDragPoints, dx))
        let absMag = abs(signedMag)
        if absMag <= deadzonePoints {
            moveAxis = 0
        } else {
            let scaled = (absMag - deadzonePoints) / (maxDragPoints - deadzonePoints)
            moveAxis = (signedMag < 0 ? -scaled : scaled).clamped(-1, 1)
        }
    }

    // MARK: - Crown

    /// Called from view's WKCrownDelegate adapter. Treat each "tick" of >= 30°
    /// as a discrete power-up trigger; ignore continuous rotation.
    private var crownAccumulated: CGFloat = 0
    func crownDidRotate(by delta: CGFloat) {
        crownAccumulated += delta
        if abs(crownAccumulated) >= 30 {
            powerUpEvents.send(())
            crownAccumulated = 0
        }
    }

    func crownPressed() {
        pauseEvents.send(())
    }
}

private extension Comparable {
    func clamped(_ lo: Self, _ hi: Self) -> Self {
        min(max(self, lo), hi)
    }
}
