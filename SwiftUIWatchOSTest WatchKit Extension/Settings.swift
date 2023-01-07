import SwiftUI
import AVFoundation

class Settings: ObservableObject {
    static let shared = Settings()

    var engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    var tsf: OpaquePointer
    var outputFormat = AVAudioFormat()

    init() {
        let soundFontPath = Bundle.main.path(forResource: "GMGSx", ofType: "sf2")
        tsf = tsf_load_filename(soundFontPath)

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)

        updateOutputFormat()
    }

    // For simplicity, this object assumes the outputFormat does not change during its lifetime.
    // It's important to watch for route changes, and recreate this object if they occur. For details, see:
    // https://developer.apple.com/documentation/avfaudio/avaudiosession/responding_to_audio_session_route_changes
    func updateOutputFormat() {
        outputFormat = engine.mainMixerNode.outputFormat(forBus: 0)
    }

    func prepare() throws {
        // Start the engine
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try engine.start()
        playerNode.play()

        updateOutputFormat()

        // Configure TSF. The only important thing here is the sample rate, which can be different on different hardware.
        // Core Audio has a defined format of "deinterleaved 32-bit floating point."
        tsf_set_output(tsf,
                       TSF_STEREO_UNWEAVED,            // mode
                       Int32(outputFormat.sampleRate), // sampleRate
                       0)                              // gain
    }

    func play() {
        tsf_note_on(tsf,
                    0,   // preset_index
                    60,  // key (middle C)
                    1.0) // velocity

        // These tones have a long falloff, so you want a lot of source data. This is 10s.
        let frameCount = 10 * Int(outputFormat.sampleRate)

        // Create a buffer for the samples
        let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = buffer.frameCapacity

        // Render the samples. Do not mix.
        let ptr = buffer.mutableAudioBufferList.pointee.mBuffers.mData?.assumingMemoryBound(to: Float.self)
        tsf_render_float(tsf,
                         ptr,                // buffer
                         Int32(frameCount),  // samples
                         0)                  // mixing (do not mix)

        // All done. Play the buffer, interrupting whatever is currently playing
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }
}
