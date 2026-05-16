import SwiftUI

struct RootView: View {
    @AppStorage("onboarded") private var onboarded = false
    @AppStorage("screenshotMode") private var screenshotMode: String = ""

    var body: some View {
        switch screenshotMode {
        case "messagesCompact":
            MessagesScreenshotHost(isExpanded: false)
        case "messagesExpanded":
            MessagesScreenshotHost(isExpanded: true)
        default:
            if onboarded {
                BrowserView()
            } else {
                OnboardingView(onDone: { onboarded = true })
            }
        }
    }
}
