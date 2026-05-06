import SwiftUI

/// Visual representation of the joystick state. Renders above the game scene.
/// Critical: `.allowsHitTesting(false)` — the gesture is captured by the
/// SpriteKit view underneath. This overlay is purely a render of state.
struct JoystickOverlay: View {
    @ObservedObject var input: InputController

    var body: some View {
        GeometryReader { geo in
            ZStack {
                track(in: geo.size)
                    .position(x: geo.size.width / 2, y: geo.size.height - 18)
                if case .active(let origin, let thumb) = input.joystick {
                    activeIndicator(origin: origin, thumb: thumb, in: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func track(in size: CGSize) -> some View {
        Capsule()
            .fill(.white.opacity(0.06))
            .frame(width: min(size.width - 16, 120), height: 6)
            .overlay(
                Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5)
            )
    }

    @ViewBuilder
    private func activeIndicator(origin: CGPoint, thumb: CGPoint, in size: CGSize) -> some View {
        let dx = thumb.x - origin.x
        // Visual thumb pinned to bottom row, x offset relative to origin.
        let thumbX = (size.width / 2) + max(-50, min(50, dx))
        ZStack {
            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: 22, height: 22)
                .position(x: thumbX, y: size.height - 18)
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .position(x: thumbX, y: size.height - 18)
        }
        .transition(.opacity.animation(.easeOut(duration: 0.15)))
    }
}
