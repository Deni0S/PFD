import SwiftUI

@main
struct PFDApp: App {
    var body: some Scene {
        WindowGroup {
            PFDView()
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
