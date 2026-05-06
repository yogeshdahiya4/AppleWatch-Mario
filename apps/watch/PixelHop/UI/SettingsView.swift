import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: GameSession
    @AppStorage("pixelhop.audioEnabled") private var audioEnabled: Bool = true
    @AppStorage("pixelhop.hapticsEnabled") private var hapticsEnabled: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let id = session.deviceIdentity {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PROFILE")
                            .font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.secondary)
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundStyle(.orange)
                            Text("@\(id.nickname)").font(.system(size: 14, weight: .semibold))
                            Spacer()
                        }
                        Text("Device ID")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text(id.id.uuidString.prefix(13) + "…")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $audioEnabled) {
                    Label("Sound", systemImage: "speaker.wave.2.fill")
                }
                Toggle(isOn: $hapticsEnabled) {
                    Label("Haptics", systemImage: "waveform.path")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("ABOUT")
                        .font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.secondary)
                    Text("PixelHop v1.0").font(.caption)
                    Text("Code MIT • Art CC0").font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle("Settings")
    }
}
