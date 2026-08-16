import Testing

@testable import RadioSharkKit

@Suite("FrequencyCodec")
struct FrequencyCodecTests {
    // raw = (MHz * 20) - 3
    @Test(
        "FMエンコード",
        arguments: [
            (megahertz: 87.5, hi: UInt8(0x06), lo: UInt8(0xD3)),  // raw = 1747
            (megahertz: 104.5, hi: UInt8(0x08), lo: UInt8(0x27)),  // raw = 2087
            (megahertz: 107.9, hi: UInt8(0x08), lo: UInt8(0x6B)),  // raw = 2155
        ]
    )
    func fmEncoding(megahertz: Double, hi: UInt8, lo: UInt8) {
        let encoded = FrequencyCodec.encodeFM(megahertz: megahertz)
        #expect(encoded.hi == hi)
        #expect(encoded.lo == lo)
    }

    // raw = (kHz * 4) + 16300
    @Test(
        "AMエンコード",
        arguments: [
            (kilohertz: 530, hi: UInt8(0x47), lo: UInt8(0xF4)),  // raw = 18420
            (kilohertz: 1000, hi: UInt8(0x4F), lo: UInt8(0x4C)),  // raw = 20300
            (kilohertz: 1710, hi: UInt8(0x5A), lo: UInt8(0x64)),  // raw = 23140
        ]
    )
    func amEncoding(kilohertz: Int, hi: UInt8, lo: UInt8) {
        let encoded = FrequencyCodec.encodeAM(kilohertz: kilohertz)
        #expect(encoded.hi == hi)
        #expect(encoded.lo == lo)
    }
}

@Suite("HIDReports")
struct HIDReportsTests {
    @Test("青色LEDレポートは0x83で始まる7バイト")
    func blueLightReport() {
        let report = HIDReports.blueLight(level: 100)
        #expect(report == [0x83, 100, 0, 0, 0, 0, 0])
    }

    @Test("赤色LEDレポートは0x84で始まる7バイト")
    func redLightReport() {
        let report = HIDReports.redLight(level: 127)
        #expect(report == [0x84, 127, 0, 0, 0, 0, 0])
    }

    @Test("FMチューニングレポートのバンドバイトは0x28")
    func fmTuningReport() {
        let report = HIDReports.fm(megahertz: 80.0)
        // raw = 80*20-3 = 1597 = 0x063D
        #expect(report == [0x81, 0x06, 0x3D, 0xF3, 0x36, 0x00, 0x28])
    }

    @Test("AMチューニングレポートのバンドバイトは0x24")
    func amTuningReport() {
        let report = HIDReports.am(kilohertz: 1710)
        #expect(report == [0x81, 0x5A, 0x64, 0x33, 0x04, 0x00, 0x24])
    }
}
