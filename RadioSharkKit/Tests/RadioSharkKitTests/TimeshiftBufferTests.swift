import Testing

@testable import RadioSharkKit

@Suite("TimeshiftBuffer")
struct TimeshiftBufferTests {
    @Test("容量はサンプルレート×分×チャンネル数から算出される")
    func capacityFramesComputedFromMinutes() {
        // 1秒分(sampleRate=10, 1/60分)、ステレオ
        let buffer = TimeshiftBuffer(sampleRate: 10, channelCount: 2, capacityMinutes: 1.0 / 60.0)
        #expect(buffer.capacityFrames == 10)
    }

    @Test("書き込んだステレオフレームを往復できる")
    func writeAndReadRoundTrip() {
        var buffer = TimeshiftBuffer(sampleRate: 10, channelCount: 2, capacityMinutes: 1.0 / 60.0)
        // 3フレーム(L,R)×3
        buffer.write(interleaved: [1, 1, 2, 2, 3, 3])
        #expect(buffer.liveFrame == 3)
        #expect(buffer.oldestAvailableFrame == 0)
        #expect(buffer.read(fromFrame: 0, frameCount: 3) == [1, 1, 2, 2, 3, 3])
    }

    @Test("容量を超えると古いフレームからoldestAvailableFrameが進む")
    func oldestAvailableFrameAdvancesOnWrap() {
        var buffer = TimeshiftBuffer(sampleRate: 10, channelCount: 2, capacityMinutes: 1.0 / 60.0)  // capacity = 10 frames
        for frame in 0..<15 {
            let value = Float(frame)
            buffer.write(interleaved: [value, value])
        }
        #expect(buffer.liveFrame == 15)
        #expect(buffer.oldestAvailableFrame == 5)
        #expect(buffer.read(fromFrame: 0, frameCount: 1) == nil)
        #expect(buffer.read(fromFrame: 5, frameCount: 1) == [5, 5])
    }
}
