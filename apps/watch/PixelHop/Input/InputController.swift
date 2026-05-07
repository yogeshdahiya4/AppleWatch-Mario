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
    /// Minimum upward velocity (points per frame) to count as a jump flick.
    var flickThreshold: CGFloat = 5.0
    /// Minimum total upward displacement during the flick to count.
    var flickMinDisplacement: CGFloat = 12
    /// Window of frames over which to average vertical velocity.
    var flickWindow: Int = 4

    // MARK: - Internal

    private struct DragState {
        var origin: CGPoint
        var current: CGPoint
        var startedAt: TimeInterval
        var verticalSamples: [CGFloat] = []   // dy per sample
    }

    private var drag: DragState?
    /// Has the current touch already triggered a jump? (prevents repeat-fire.)
    private var jumpTriggeredThisTouch: Bool = false

    enum JoystickState: Equatable {
        case idle
        case active(origin: CGPoint, thumb: CGPoint)
    }

    // MARK: - Touch handling

    /// Called by the scene/view on touchDown.
    func touchDown(at p: CGPoint, time: TimeInterval) {
        drag = DragState(origin: p, current: p, startedAt: time)
        jumpTriggeredThisTouch = false
        joystick = .active(origin: p, thumb: p)
        recomputeAxes()
    }

    /// Called every time the finger moves.
    func touchMoved(to p: CGPoint, time _: TimeInterval) {
        guard var d = drag else { return }
        let dy = p.y - d.current.y
        d.verticalSamples.append(dy)
        if d.verticalSamples.count > flickWindow {
            d.verticalSamples.removeFirst()
        }
        d.current = p
        drag = d
        joystick = .active(origin: d.origin, thumb: p)
        detectFlickIfReady()
        recomputeAxes()
    }

    /// Called on touchUp. If the lift itself was a strong upward swipe, also fire jump.
    func touchUp(at p: CGPoint, time _: TimeInterval) {
        if let d = drag {
            let totalDy = p.y - d.origin.y
            // If finger flew up significantly without an in-drag flick already firing
            if !jumpTriggeredThisTouch, totalDy > flickMinDisplacement {
                let mag = min(1.0, abs(totalDy) / 60)
                jumpEvents.send(mag)
            }
        }
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

    private func detectFlickIfReady() {
        guard !jumpTriggeredThisTouch, let d = drag else { return }
        guard d.verticalSamples.count >= flickWindow else { return }
        // Positive sum = finger is moving UP in screen coords.
        // SpriteKit uses bottom-origin Y (up = positive), but watchOS UIKit
        // touches have top-origin Y. The view layer flips this before passing
        // to us so up = positive here.
        let upwardSum = d.verticalSamples.reduce(0, +)
        let upwardAvg = upwardSum / CGFloat(d.verticalSamples.count)
        let displacement = d.current.y - d.origin.y
        if upwardAvg >= flickThreshold, displacement >= flickMinDisplacement {
            jumpTriggeredThisTouch = true
            let magnitude = min(1.0, max(0.4, upwardAvg / 12))
            jumpEvents.send(magnitude)
            jumpHeld = true
            // jumpHeld auto-clears on touch up; that's the variable-height window.
        }
    }

    private func recomputeAxes() {
        guard let d = drag else { moveAxis = 0; return }
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
