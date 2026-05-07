import SwiftUI

/// Visual representation of the joystick + an explicit JUMP button.
///
/// **Joystick (lower-left):** circular dual-ring stick. The base ring stays
/// fixed; the thumb circle follows the finger's horizontal offset from the
/// drag-origin, capped at the ring radius. Pure visual — gesture is captured
/// at the SpriteKit view layer so this can use `.allowsHitTesting(false)`
/// for the *base*, but the JUMP button needs hit-testing.
///
/// **Jump button (lower-right):** a dedicated circular button. Flick-up still
/// works for power players, but the button is what new users will discover.
struct JoystickOverlay: View {
    @ObservedObject var input: InputController
    /// Called when the jump button is tapped (and held → variable jump height).
    var onJumpDown: () -> Void
    var onJumpUp: () -> Void

    @State private var jumpPressed = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                joystickBase(in: geo.size)
                    .allowsHitTesting(false)
                if case .active(let origin, let thumb) = input.joystick {
                    joystickThumb(origin: origin, thumb: thumb, in: geo.size)
                        .allowsHitTesting(false)
                }
                jumpButton(in: geo.size)
            }
        }
    }

    // MARK: - Joystick base + thumb

    private func joystickBase(in size: CGSize) -> some View {
        let radius: CGFloat = 32
        let cx: CGFloat = radius + 8
        let cy: CGFloat = size.height - radius - 8
        return ZStack {
            Circle()
                .fill(.white.opacity(0.06))
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1.0))
                .frame(width: radius * 2, height: radius * 2)
                .position(x: cx, y: cy)
            // Subtle dot in the middle so the rest position is obvious.
            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: 6, height: 6)
                .position(x: cx, y: cy)
        }
    }

    private func joystickThumb(origin: CGPoint, thumb: CGPoint, in size: CGSize) -> some View {
        let radius: CGFloat = 32
        let cx: CGFloat = radius + 8
        let cy: CGFloat = size.height - radius - 8
        let rawDx = thumb.x - origin.x
        let rawDy = origin.y - thumb.y    // input flips coords already; here screen-y
        let dx = max(-radius, min(radius, rawDx))
        let dy = max(-radius, min(radius, rawDy))
        return ZStack {
            // Inner thumb ball — opaque, follows the finger
            Circle()
                .fill(.white)
                .frame(width: 22, height: 22)
                .shadow(color: .white.opacity(0.4), radius: 6)
                .position(x: cx + dx, y: cy + dy)
        }
        .transition(.opacity.animation(.easeOut(duration: 0.12)))
    }

    // MARK: - Jump button

    private func jumpButton(in size: CGSize) -> some View {
        let r: CGFloat = 30
        let cx: CGFloat = size.width - r - 8
        let cy: CGFloat = size.height - r - 8
        return Button {
            // momentary action handled via gesture below
        } label: {
            ZStack {
                Circle()
                    .fill(jumpPressed
                            ? Color.green.opacity(0.55)
                            : Color.green.opacity(0.30))
                    .overlay(Circle().stroke(.green.opacity(0.85), lineWidth: 1.4))
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: r * 2, height: r * 2)
            .scaleEffect(jumpPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: jumpPressed)
        }
        .buttonStyle(.plain)
        .position(x: cx, y: cy)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !jumpPressed {
                        jumpPressed = true
                        onJumpDown()
                    }
                }
                .onEnded { _ in
                    jumpPressed = false
                    onJumpUp()
                }
        )
    }
}
