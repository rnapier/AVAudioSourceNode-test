import SwiftUI
import AVFoundation

class Settings: ObservableObject {
    static let shared = Settings()

    var engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()

    func prepare() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try engine.start()
            playerNode.play()
        } catch {
            print(error)
        }
    }

    func play() {
        // This is the output format. We'll need to get to this eventually.
        let outputFormat = engine.mainMixerNode.outputFormat(forBus: 0)

        // It would be best to generate this in the output format from the start.
        // I don't know if this library can do that, so I'll convert it to have a general solution.
        // Generally you'd create this format object once and cache it, but I'm keeping all the code together.
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        )!

        // These tones have a long falloff, so you want a lot of source data. This is 10s.
        let frameCount = 10 * Int(audioFormat.sampleRate)

        // Get the samples
        let data = SoundFontHelper.sharedInstance().getSound(Int32(frameCount))!

        // Copy the samples into an audio buffer. It would be better to do this directly in getSound, rather
        // than creating a Data, and then copying it, but this is pretty straightforward.
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount))!
        data.withUnsafeBytes { bytes in
            buffer.frameLength = buffer.frameCapacity
            let audioBuffer = buffer.audioBufferList.pointee.mBuffers
            audioBuffer.mData?.copyMemory(from: bytes.baseAddress!, byteCount: Int(audioBuffer.mDataByteSize))
        }

        // Now convert it with an AVAudioConverter
        let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(frameCount))!

        // It should be impossible for this conversion to fail. This could be done with a simpler call
        // to `convert(to:from:)` if you make sure to create the audio at the right sampling rate from outputFormat.
        // This version of the call works for any supported format.
        // It's usually best to create this converter once, and cache it, but this approach keeps the code simpler.
        let converter = AVAudioConverter(from: audioFormat, to: outputFormat)!
        converter.convert(to: outputBuffer, error: nil) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        // All done. Play the buffer, interrupting whatever is currently playing
        playerNode.scheduleBuffer(outputBuffer, at: nil, options: .interrupts)
    }
}
