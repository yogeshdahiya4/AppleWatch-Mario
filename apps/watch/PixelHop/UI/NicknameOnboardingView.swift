import SwiftUI

struct NicknameOnboardingView: View {
    var onCompleted: (DeviceIdentity) -> Void

    @EnvironmentObject private var session: GameSession
    @State private var nickname: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private static let validPattern = "^[A-Za-z0-9_\\-.]{2,16}$"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome!")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .orange.opacity(0.45), radius: 6, x: 0, y: 0)

                Text("Pick a name for the leaderboard. 2-16 chars. letters, digits, _ - .")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                TextField("Nickname", text: $nickname)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                Button(action: { Task { await submit() } }) {
                    HStack {
                        if isSubmitting {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(isSubmitting ? "Saving" : "Let's go")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isSubmitting || !isValid)
            }
            .padding(.horizontal, 6)
        }
    }

    private var isValid: Bool {
        nickname.range(of: Self.validPattern, options: .regularExpression) != nil
    }

    @MainActor
    private func submit() async {
        guard isValid else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let id = try await DeviceIdentity.registerNew(nickname: nickname, api: session.api)
            try id.persistToKeychain()
            onCompleted(id)
        } catch APIError.conflict {
            errorMessage = "That nickname is taken. Try another."
        } catch APIError.offline {
            errorMessage = "Offline. Connect and try again."
        } catch {
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }
}
