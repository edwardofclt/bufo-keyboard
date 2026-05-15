import SwiftUI
import UIKit

struct OnboardingView: View {
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Welcome to Bufo Keyboard")
                    .font(.largeTitle.bold())

                Text("A keyboard of bufos you can drop into any app.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Step(number: "1",
                     title: "Open Settings",
                     description: "Settings → General → Keyboard → Keyboards → Add New Keyboard…")

                Step(number: "2",
                     title: "Pick Bufos",
                     description: "Tap 'Bufos' in the list of third-party keyboards.")

                Step(number: "3",
                     title: "Turn on Full Access",
                     description: "Tap Bufos again and enable Allow Full Access. This is required for the keyboard to put bufos on the clipboard so you can paste them as stickers.")

                Step(number: "4",
                     title: "Switch to Bufos in any app",
                     description: "Tap the 🌐 globe key on the keyboard until Bufos appears, tap a bufo to copy it, then long-press the message field and Paste.")

                Spacer(minLength: 8)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 8)

                Button(action: onDone) {
                    Text("Browse Bufos")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.2))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
        }
    }
}

private struct Step: View {
    let number: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.title2.bold())
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview { OnboardingView(onDone: {}) }
