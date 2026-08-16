/// radioSHARK 2（7バイトHIDレポート）向けのレポート生成。
///
/// バイトレイアウトの出典は `docs/hardware-protocol.md` §4、実機検証結果は同§11。
/// ハードウェア側にレポートIDの概念はなく、常に7バイトの生データを送る。
public enum HIDReports {
    /// 青色LED（本体アイコン）の輝度。0（消灯）〜127。
    public static func blueLight(level: UInt8) -> [UInt8] {
        [0x83, level, 0, 0, 0, 0, 0]
    }

    /// 赤色LED（録音中インジケーター）の輝度。0（消灯）〜127。
    public static func redLight(level: UInt8) -> [UInt8] {
        [0x84, level, 0, 0, 0, 0, 0]
    }

    /// 指定バンド・周波数バイトへのチューニングレポート。
    public static func tuning(band: Band, hi: UInt8, lo: UInt8) -> [UInt8] {
        let (b3, b4): (UInt8, UInt8) = band == .fm ? (0xF3, 0x36) : (0x33, 0x04)
        return [0x81, hi, lo, b3, b4, 0x00, band.rawValue]
    }

    /// FM周波数（MHz）へのチューニングレポート。
    public static func fm(megahertz: Double) -> [UInt8] {
        let (hi, lo) = FrequencyCodec.encodeFM(megahertz: megahertz)
        return tuning(band: .fm, hi: hi, lo: lo)
    }

    /// AM周波数（kHz）へのチューニングレポート。
    public static func am(kilohertz: Int) -> [UInt8] {
        let (hi, lo) = FrequencyCodec.encodeAM(kilohertz: kilohertz)
        return tuning(band: .am, hi: hi, lo: lo)
    }
}
