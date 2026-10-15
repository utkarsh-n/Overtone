import SwiftUI

@main
struct OvertoneApp: App {
    @State private var instrument = InstrumentModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(model: instrument)
                .preferredColorScheme(.dark)
                .tint(Palette.mint)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { instrument.suspend() }
                }
        }
    }
}
