import SwiftUI
import AVFoundation

struct ContentView: View {
    @ObservedObject var settings = Settings.shared

    init() {
        settings.prepare()
    }

    var body: some View {
        Button("Play Sound") {
            SoundFontHelper.sharedInstance().playSound()
            settings.play()
        }
    }
}
