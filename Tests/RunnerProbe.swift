import SwiftUI

// Built as a tiny, independent simulator app only in opt-in smoke tests.
// It intentionally has no FIELD/OS framework/package dependencies or hardware.
@main
struct RunnerProbe: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 16) {
                Text("SIMULATOR BASELINE")
                    .font(.title.bold().monospaced())
                Text("INDEPENDENT SWIFTUI APP")
                    .font(.caption.monospaced())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(Color.green)
            .background(Color.black)
            .onAppear { print("FIELD_CI_RUNNER_BASELINE_VISIBLE") }
        }
    }
}
