import SwiftUI
import UIKit

struct MessagesScreenshotHost: View {
    let isExpanded: Bool

    var body: some View {
        GeometryReader { geo in
            let drawerHeight = isExpanded ? geo.size.height * 0.78 : min(320, geo.size.height * 0.42)

            ZStack(alignment: .bottom) {
                conversationBackdrop
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                drawer
                    .frame(height: drawerHeight)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 12, y: -2)
            }
            .ignoresSafeArea(.keyboard)
        }
    }

    private var conversationBackdrop: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Spacer()
                VStack(spacing: 2) {
                    Circle().fill(Color.secondary.opacity(0.25)).frame(width: 32, height: 32)
                    Text("Frog Friends").font(.caption2)
                }
                Spacer()
                Image(systemName: "video").font(.title3).foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(Color(uiColor: .secondarySystemBackground))

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    bubble("Wait til you see these new bufos 🐸", fromMe: false)
                    bubble("They've got bufos for every mood!", fromMe: false)
                    bubble("Send me one of the chefs", fromMe: true)
                    bubble("On it 👨‍🍳", fromMe: false)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func bubble(_ text: String, fromMe: Bool) -> some View {
        HStack {
            if fromMe { Spacer(minLength: 40) }
            Text(text)
                .font(.callout)
                .foregroundStyle(fromMe ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(fromMe ? Color.accentColor : Color.secondary.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            if !fromMe { Spacer(minLength: 40) }
        }
    }

    private var drawer: some View {
        MessagesRootView(
            onSelectBufo: { _ in },
            onRequestExpand: { },
            isExpanded: isExpanded
        )
    }
}
