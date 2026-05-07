import Combine
import SpriteKit
import SwiftUI

/// Hosts a `GameScene` plus the joystick overlay and HUD, and walks the
/// player through the world (1-1 → 1-4) when launched from "Play".
struct GameContainerView: View {
    let startingLevel: LevelID

    @EnvironmentObject private var session: GameSession
    @Environment(\.dismiss) private var dismiss
    @State private var currentLevel: LevelID
    @State private var sessionStats = WorldRunStats()
    @State private var scene: GameScene?
    @State private var hud: GameScene.HUDState = .start
    @State private var subs = Set<AnyCancellable>()
    @State private var crownValue: Double = 0
    @StateObject private var input = InputController()

    init(startingLevel: LevelID) {
        self.startingLevel = startingLevel
        _currentLevel = State(initialValue: startingLevel)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // The game scene — SpriteView is the SwiftUI-native renderer.
                if let scene {
                    SpriteView(scene: scene, preferredFramesPerSecond: 60)
                        .ignoresSafeArea()
                        .gesture(dragGesture(viewSize: geo.size))
                }

                // Joystick overlay (bottom-right). Jumps come from flicking up.
                JoystickOverlay(input: input)
                    .frame(width: geo.size.width, height: geo.size.height)

                // HUD
                VStack {
                    HUDView(state: hud)
                        .padding(.top, 4)
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .focusable(true)
        .digitalCrownRotation(
            $crownValue,
            from: -360, through: 360, by: 5,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { oldValue, newValue in
            input.crownDidRotate(by: CGFloat(newValue - oldValue))
        }
        .onAppear {
            rebuildScene()
            #if DEBUG
            if ProcessInfo.processInfo.environment["PIXELHOP_DEBUG_AUTOPLAY_INPUT"] == "1" {
                startAutoInputLoop()
            }
            #endif
        }
        .onChange(of: currentLevel) { _, _ in rebuildScene() }
    }

    #if DEBUG
    /// Drives the input controller in a loop: walk right, jump, repeat.
    /// Used for screen-recording demo videos.
    @MainActor
    private func startAutoInputLoop() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            // Stay touching down on the joystick area, drag right
            let now = { Date().timeIntervalSinceReferenceDate }
            input.touchDown(at: CGPoint(x: 40, y: 40), time: now())
            for _ in 0..<300 {
                try? await Task.sleep(for: .milliseconds(50))
                input.touchMoved(to: CGPoint(x: 90, y: 40), time: now())
                if Int.random(in: 0..<10) == 0 {
                    input.jumpButtonDown()
                    try? await Task.sleep(for: .milliseconds(180))
                    input.jumpButtonUp()
                }
            }
            input.touchUp(at: CGPoint(x: 90, y: 40), time: now())
        }
    }
    #endif

    private func dragGesture(viewSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Convert UIKit-style top-origin to bottom-origin for InputController.
                let p = CGPoint(x: value.location.x, y: viewSize.height - value.location.y)
                let now = Date().timeIntervalSinceReferenceDate
                if input.joystick == .idle {
                    input.touchDown(at: p, time: now)
                } else {
                    input.touchMoved(to: p, time: now)
                }
            }
            .onEnded { value in
                let p = CGPoint(x: value.location.x, y: viewSize.height - value.location.y)
                input.touchUp(at: p, time: Date().timeIntervalSinceReferenceDate)
            }
    }

    private func rebuildScene() {
        let lvl = LevelLoader.load(currentLevel)
        let s = GameScene(level: lvl, input: input, viewportSize: CGSize(width: 198, height: 242))
        // Wire output streams
        var bag = Set<AnyCancellable>()
        s.$hudState
            .receive(on: DispatchQueue.main)
            .sink { hud = $0 }
            .store(in: &bag)
        s.levelEnded
            .receive(on: DispatchQueue.main)
            .sink { result in Task { await handleLevelEnd(result) } }
            .store(in: &bag)
        subs = bag
        scene = s
    }

    @MainActor
    private func handleLevelEnd(_ result: GameRunResult) async {
        sessionStats.append(result)
        session.save.record(result)
        if let identity = session.deviceIdentity {
            await session.scoreSubmitter.submit(
                APIClient.ScoreSubmission(
                    level: result.level.rawValue,
                    score: result.score,
                    time_ms: result.timeMs,
                    coins: result.coins,
                    world_completed: false
                ),
                identity: identity
            )
        }
        if result.died {
            dismiss()
            return
        }
        if let next = result.level.next {
            currentLevel = next
        } else {
            // World complete — submit aggregate
            let total = sessionStats.totalScore
            let totalMs = sessionStats.totalTimeMs
            if let identity = session.deviceIdentity {
                let agg = GameRunResult(
                    level: .world1_1,
                    score: total,
                    coins: sessionStats.totalCoins,
                    timeMs: totalMs,
                    died: false,
                    worldCompleted: true
                )
                session.save.record(agg)
                await session.scoreSubmitter.submit(
                    APIClient.ScoreSubmission(
                        level: "world1",
                        score: total,
                        time_ms: totalMs,
                        coins: sessionStats.totalCoins,
                        world_completed: true
                    ),
                    identity: identity
                )
            }
            dismiss()
        }
    }
}

/// Aggregates a single end-to-end world run.
struct WorldRunStats {
    var perLevel: [LevelID: GameRunResult] = [:]

    mutating func append(_ r: GameRunResult) {
        perLevel[r.level] = r
    }
    var totalScore: Int { perLevel.values.map(\.score).reduce(0, +) }
    var totalCoins: Int { perLevel.values.map(\.coins).reduce(0, +) }
    var totalTimeMs: Int { perLevel.values.map(\.timeMs).reduce(0, +) }
}
