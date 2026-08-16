import Testing

@testable import RadioSharkKit

@Suite("AudioDeviceMatch")
struct AudioDeviceMatchTests {
    // findDeviceID() 自体はCoreAudio/実機依存のためここではテストしない。
    // 実機確認はradioaudio-cliで行う(docs/implementation-plan.md Phase 2)。

    @Test("デバイス名\"radioSHARK\"にマッチする")
    func matchesExpectedDeviceName() {
        #expect(AudioDeviceMatch.matches(deviceName: "radioSHARK"))
    }

    @Test(
        "無関係なデバイス名にはマッチしない",
        arguments: ["radioshark", "RadioSHARK", "MacBook Pro Microphone", "radioSHARK 2", ""]
    )
    func doesNotMatchOtherNames(name: String) {
        #expect(!AudioDeviceMatch.matches(deviceName: name))
    }
}
