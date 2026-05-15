import SwiftUI

struct RootView: View {
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        if onboarded {
            BrowserView()
        } else {
            OnboardingView(onDone: { onboarded = true })
        }
    }
}
