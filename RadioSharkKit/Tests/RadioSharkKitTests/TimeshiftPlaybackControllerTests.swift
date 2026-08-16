import Testing

@testable import RadioSharkKit

@Suite("TimeshiftPlaybackController")
struct TimeshiftPlaybackControllerTests {
    @Test("初期状態はliveで、advanceLiveに追従する")
    func startsLiveAndTracksLiveFrame() {
        var controller = TimeshiftPlaybackController(sampleRate: 100)
        #expect(controller.mode == .live)
        controller.advanceLive(toFrame: 1000, oldestAvailableFrame: 0)
        #expect(controller.currentFrame == 1000)
    }

    @Test("Rewindを押すとseekingBackになり、tickでcurrentFrameが後退する")
    func rewindMovesPositionBackward() {
        var controller = TimeshiftPlaybackController(sampleRate: 100)
        controller.advanceLive(toFrame: 1000, oldestAvailableFrame: 0)
        controller.pressRewind()
        #expect(controller.mode == .seekingBack(rateIndex: 0))
        controller.tick(elapsedSeconds: 1)
        // rate=1x, sampleRate=100 → 100フレーム後退
        #expect(controller.currentFrame == 900)
    }

    @Test("Rewindを連打すると速度(rateIndex)が上がる")
    func repeatedRewindIncreasesRate() {
        var controller = TimeshiftPlaybackController(sampleRate: 100)
        controller.advanceLive(toFrame: 10_000, oldestAvailableFrame: 0)
        controller.pressRewind()
        controller.pressRewind()
        controller.pressRewind()
        #expect(controller.mode == .seekingBack(rateIndex: 2))
        #expect(controller.currentRate == TimeshiftPlaybackController.rates[2])
    }

    @Test("oldestAvailableFrameまで後退すると停止してpausedになる")
    func rewindClampsAtOldestAvailableFrame() {
        var controller = TimeshiftPlaybackController(sampleRate: 100)
        controller.advanceLive(toFrame: 500, oldestAvailableFrame: 400)
        controller.pressRewind()
        controller.tick(elapsedSeconds: 10)  // 十分すぎる時間
        #expect(controller.currentFrame == 400)
        #expect(controller.mode == .paused)
    }

    @Test("FastForwardでliveまで到達すると自動的にliveへ復帰する")
    func fastForwardReturnsToLiveAtEdge() {
        var controller = TimeshiftPlaybackController(sampleRate: 100)
        controller.advanceLive(toFrame: 1000, oldestAvailableFrame: 0)
        controller.pressRewind()
        controller.tick(elapsedSeconds: 1)  // currentFrame = 900
        controller.pressFastForward()
        controller.tick(elapsedSeconds: 10)  // 十分すぎる時間
        #expect(controller.currentFrame == 1000)
        #expect(controller.mode == .live)
    }

    @Test("既にliveの状態でFastForwardを押しても何も起きない")
    func fastForwardIsNoOpWhenAlreadyLive() {
        var controller = TimeshiftPlaybackController(sampleRate: 100)
        controller.advanceLive(toFrame: 1000, oldestAvailableFrame: 0)
        controller.pressFastForward()
        #expect(controller.mode == .live)
    }

    @Test("skipBack/skipAheadは指定秒数ぶん移動し、範囲でクランプされる")
    func skipMovesByFixedSecondsAndClamps() {
        var controller = TimeshiftPlaybackController(sampleRate: 100)
        controller.advanceLive(toFrame: 1000, oldestAvailableFrame: 0)
        controller.skipBack(seconds: 3)
        #expect(controller.currentFrame == 700)
        #expect(controller.mode == .paused)

        controller.skipBack(seconds: 100)  // 0未満にはならない
        #expect(controller.currentFrame == 0)

        controller.skipAhead(seconds: 100)  // liveを超えない
        #expect(controller.currentFrame == 1000)
        #expect(controller.mode == .live)
    }

    @Test("pressPlayPauseはタイムシフト再生のみ停止/再開する")
    func playPauseTogglesSeekingState() {
        var controller = TimeshiftPlaybackController(sampleRate: 100)
        controller.advanceLive(toFrame: 1000, oldestAvailableFrame: 0)
        controller.skipBack(seconds: 1)
        #expect(controller.mode == .paused)
        controller.pressPlayPause()
        #expect(controller.mode == .seekingForward(rateIndex: 0))
        controller.pressPlayPause()
        #expect(controller.mode == .paused)
    }

    @Test("goLiveは即座にliveへ復帰する")
    func goLiveJumpsImmediately() {
        var controller = TimeshiftPlaybackController(sampleRate: 100)
        controller.advanceLive(toFrame: 1000, oldestAvailableFrame: 0)
        controller.pressRewind()
        controller.tick(elapsedSeconds: 1)
        controller.goLive()
        #expect(controller.mode == .live)
        #expect(controller.currentFrame == 1000)
    }
}
