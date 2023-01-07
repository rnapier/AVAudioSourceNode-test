import SwiftUI
import AVFoundation

struct ContentView: View {
    @ObservedObject var settings = Settings.shared

    init() {
        try! settings.prepare()
    }

    var body: some View {
        Button("Play Sound") {
            settings.play()
        }
    }
}
