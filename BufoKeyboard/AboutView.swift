import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("About") {
                    Text("Bufo Keyboard puts a keyboard of bufos one tap away in every app. Tap a bufo to copy it, then long-press the message field and Paste to send it as a sticker / image attachment.")
                }

                Section("Enable the keyboard") {
                    Link("Open iOS Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                    Text("Settings → General → Keyboard → Keyboards → Add New Keyboard → Bufos → Allow Full Access")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Credits") {
                    Link("Bufo assets — bufo.fun",
                         destination: URL(string: "https://github.com/tfritzy/bufo.fun")!)
                    Link("Original collection — all-the-bufo",
                         destination: URL(string: "https://github.com/knobiknows/all-the-bufo")!)
                    Text("Bufo assets are distributed under the MIT License per the bufo.fun project.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("License") {
                    Text(licenseText)
                        .font(.system(.footnote, design: .monospaced))
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var licenseText: String {
        guard let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil)
                ?? Bundle.main.url(forResource: "LICENSE", withExtension: "txt"),
              let text = try? String(contentsOf: url) else {
            return "MIT License — see LICENSE in the project repository."
        }
        return text
    }
}

#Preview { AboutView() }
