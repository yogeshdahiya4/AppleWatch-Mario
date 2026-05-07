import SwiftUI

/// Circular virtual joystick anchored at the **bottom-right** of the play area.
/// Movement = horizontal drag from the centre; jumps = flick upward (handled
/// by the underlying `InputController` from the gesture stream — no separate
/// button).
///
/// This view is rendered above the SpriteKit scene as a SwiftUI overlay and
/// uses `.allowsHitTesting(false)` since the gesture is captured at the scene
/// layer in `GameContainerView`.
struct JoystickOverlay: View {
    @ObservedObject var input: InputController

    var body: some View {
        GeometryReader { geo in
            ZStack {
                joystickBase(in: geo.size)
                if case .active(let origin, let thumb) = input.joystick {
                    joystickThumb(origin: origin, thumb: thumb, in: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Layout

    private static let radius: CGFloat = 32
    private static let bottomMargin: CGFloat = 8
    private static let sideMargin: CGFloat = 8

    private func anchor(in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width - Self.radius - Self.sideMargin,
            y: size.height - Self.radius - Self.bottomMargin
        )
    }

    // MARK: - Visuals

    private func joystickBase(in size: CGSize) -> some View {
        let c = anchor(in: size)
        return ZStack {
            Circle()
                .fill(.white.opacity(0.06))
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1.0))
                .frame(width: Self.radius * 2, height: Self.radius * 2)
                .position(c)
            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: 6, height: 6)
                .position(c)
        }
    }

    private func joystickThumb(origin: CGPoint, thumb: CGPoint, in size: CGSize) -> some View {
        let c = anchor(in: size)
        let rawDx = thumb.x - origin.x
        let rawDy = origin.y - thumb.y    // input layer uses y-up; this view uses y-down
        let dx = max(-Self.radius, min(Self.radius, rawDx))
        let dy = max(-Self.radius, min(Self.radius, rawDy))
        return Circle()
            .fill(.white)
            .frame(width: 22, height: 22)
            .shadow(color: .white.opacity(0.4), radius: 6)
            .position(x: c.x + dx, y: c.y + dy)
            .transition(.opacity.animation(.easeOut(duration: 0.12)))
    }
}
